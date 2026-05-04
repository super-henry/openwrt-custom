#!/bin/bash
#
# 生成设备配置对比 HTML 页面（暖阳白调 + 纸质纹理 + Dock标签栏弹性动画）
# 由 preview-config.sh --html 调用
#
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PREVIEW_SCRIPT="$SCRIPT_DIR/preview-config.sh"

DEVICE_LIST=""
CONFIG_TAGS="clean basic func test"
OUTPUT_HTML="$(pwd)/设备配置对照表.html"

usage() {
    cat <<EOF
用法: $0 [选项]
选项:
  -d "编号列表"  设备编号, 如 "1 2 3" (默认全部)
  -c "档位列表"  配置档位, 如 "basic func" (默认 clean basic func test)
  -o 文件名      输出 HTML 文件 (默认 comparison.html)
  -h             显示帮助
EOF
}

while getopts "d:c:o:h" opt; do
    case $opt in
        d) DEVICE_LIST="$OPTARG" ;;
        c) CONFIG_TAGS="$OPTARG" ;;
        o) OUTPUT_HTML="$OPTARG" ;;
        h) usage; exit 0 ;;
        *) usage; exit 1 ;;
    esac
done

[ ! -x "$PREVIEW_SCRIPT" ] && { echo "[ERROR] 无法执行 $PREVIEW_SCRIPT" >&2; exit 1; }

if [ -z "$DEVICE_LIST" ]; then
    DEVICE_LIST=$("$PREVIEW_SCRIPT" --list-devices 2>/dev/null | awk -F'\t' '{print $1}')
    [ -z "$DEVICE_LIST" ] && { echo "[ERROR] 无法获取设备列表" >&2; exit 1; }
fi

declare -A CFG ALL_GROUPS ALL_KEYS
GROUP_ORDER=()
GROUP_KEY_ORDER=()

collect_configs() {
    local device_id=$1 tag=$2 output group line key value
    output=$("$PREVIEW_SCRIPT" "$device_id" "$tag" 2>/dev/null) || {
        echo "[警告] 采集失败：设备 $device_id 档位 $tag" >&2
        return 1
    }
    group="Target Information"
    while IFS= read -r line; do
        if [[ "$line" =~ ^#[[:space:]]*----------[[:space:]]*(.*) ]]; then
            group="${BASH_REMATCH[1]}"
            continue
        fi
        if [[ "$line" =~ ^(CONFIG_[A-Za-z0-9_-]+)=(y|m) ]]; then
            key="${BASH_REMATCH[1]}"
            value="${BASH_REMATCH[2]}"
        elif [[ "$line" =~ ^#[[:space:]]*(CONFIG_[A-Za-z0-9_-]+)[[:space:]]is[[:space:]]not[[:space:]]set ]]; then
            key="${BASH_REMATCH[1]}"
            value="not set"
        else
            continue
        fi
        CFG["$device_id|$tag|$group|$key"]="$value"
        [[ -z "${ALL_GROUPS["$group"]+_}" ]] && { ALL_GROUPS["$group"]=1; GROUP_ORDER+=("$group"); }
        local gk="$group|$key"
        [[ -z "${ALL_KEYS["$gk"]+_}" ]] && { ALL_KEYS["$gk"]=1; GROUP_KEY_ORDER+=("$group" "$key"); }
    done <<< "$output"
}

echo "正在采集配置数据..."
for dev in $DEVICE_LIST; do
    for tag in $CONFIG_TAGS; do
        printf "  - 设备 %s 档位 %-6s ..." "$dev" "$tag"
        collect_configs "$dev" "$tag" && echo " 完成"
    done
done
[ ${#GROUP_ORDER[@]} -eq 0 ] && { echo "[ERROR] 无数据"; exit 1; }

TAGS_ARRAY=($CONFIG_TAGS)

js_escape() { local s="$1"; s="${s//\\/\\\\}"; s="${s//\'/\\\'}"; echo "$s"; }

echo "生成 HTML: $OUTPUT_HTML"

# ---------- 预生成所有 JavaScript 数据字符串 ----------
js_data=""
printf -v tags_array "'%s'" "${TAGS_ARRAY[0]}"
for ((i=1; i<${#TAGS_ARRAY[@]}; i++)); do
    printf -v tags_array "%s,'%s'" "$tags_array" "${TAGS_ARRAY[i]}"
done
js_data+=$'const CONFIG_TAGS = ['$tags_array$'];'$'\n'
js_data+=$'const DEVICE_ORDER = [];\nconst DEVICE_DATA = {};\nconst DEVICE_ITEMS = {};\n'

for dev in $DEVICE_LIST; do
    dev_tag=""
    while IFS=$'\t' read -r id tag; do
        [ "$id" = "$dev" ] && { dev_tag="$tag"; break; }
    done < <("$PREVIEW_SCRIPT" --list-devices 2>/dev/null)
    [ -z "$dev_tag" ] && dev_tag="设备 $dev"
    escaped_id=$(js_escape "$dev")
    escaped_tag=$(js_escape "$dev_tag")
    js_data+="DEVICE_ORDER.push({id:'$escaped_id',tag:'$escaped_tag'});"$'\n'
    js_data+="DEVICE_DATA['$escaped_id'] = {};"$'\n'
    js_data+="DEVICE_ITEMS['$escaped_id'] = {};"$'\n'

    for group in "${GROUP_ORDER[@]}"; do
        escaped_group=$(js_escape "$group")
        js_data+="DEVICE_DATA['$escaped_id']['$escaped_group'] = [];"$'\n'
        has_any=0
        i=0
        while [ $i -lt ${#GROUP_KEY_ORDER[@]} ]; do
            g="${GROUP_KEY_ORDER[$i]}"
            k="${GROUP_KEY_ORDER[$i+1]}"
            if [ "$g" = "$group" ]; then
                any_val=0
                for tag in "${TAGS_ARRAY[@]}"; do
                    raw="${CFG["$dev|$tag|$group|$k"]-}"
                    [ -n "$raw" ] && any_val=1 && break
                done
                [ $any_val -eq 1 ] && has_any=1
            fi
            i=$((i+2))
        done
        if [ $has_any -eq 1 ]; then
            js_data+="DEVICE_ITEMS['$escaped_id']['$escaped_group'] = [];"$'\n'
        fi
        i=0
        while [ $i -lt ${#GROUP_KEY_ORDER[@]} ]; do
            g="${GROUP_KEY_ORDER[$i]}"
            k="${GROUP_KEY_ORDER[$i+1]}"
            if [ "$g" = "$group" ]; then
                any_val=0
                for tag in "${TAGS_ARRAY[@]}"; do
                    raw="${CFG["$dev|$tag|$group|$k"]-}"
                    [ -n "$raw" ] && any_val=1 && break
                done
                if [ $any_val -eq 1 ]; then
                    [ $has_any -eq 1 ] && js_data+="DEVICE_ITEMS['$escaped_id']['$escaped_group'].push('$(js_escape "$k")');"$'\n'
                fi
                js_data+="DEVICE_DATA['$escaped_id']['$escaped_group'].push({key:'$(js_escape "$k")',values:{"
                first_val=true
                for tag in "${TAGS_ARRAY[@]}"; do
                    raw="${CFG["$dev|$tag|$group|$k"]-}"
                    [ "$first_val" = true ] || js_data+=","
                    js_data+="'$tag':'$(js_escape "$raw")'"
                    first_val=false
                done
                js_data+=$'}});\n'
            fi
            i=$((i+2))
        done
    done
done

# ---------- 一次性输出整个 HTML ----------
{
    cat <<'HTMLEOF'
<!DOCTYPE html>
<html lang="zh">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>设备配置对比</title>
<style>
*{box-sizing:border-box;margin:0;padding:0}

/* 纯CSS纸质纹理 */
body::before {
    content: "";
    position: fixed;
    top: 0; left: 0; right: 0; bottom: 0;
    z-index: 1;
    pointer-events: none;
    background-image: 
        repeating-conic-gradient(
            #f0ebe3 0%,
            #f0ebe3 0.003%,
            transparent 0.003%,
            transparent 0.005%
        );
    background-size: 40px 40px;
}

body {
    font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, "Helvetica Neue", Arial, sans-serif;
    background-color: #fafaf9;
    color: #1e293b;
    line-height: 1.5;
    height: 100vh;
    overflow: hidden;
    display: flex;
    flex-direction: column;
    position: relative;
}

.main-wrapper {
    width: fit-content;
    max-width: 100%;
    margin: 0 auto;
    display: flex;
    flex-direction: column;
    height: 100%;
    min-height: 0;
    position: relative;
    z-index: 2;
}

/* 标签栏 */
.tab-bar {
    display: flex;
    flex-wrap: nowrap;
    justify-content: flex-start;
    padding: 8px 0 0;
    margin: 0;
    margin-bottom: -1px;
    position: relative;
    z-index: 10;
    background: transparent;
    overflow: visible;
    overflow: hidden;
}

.tab-btn {
    padding: 8px 5px;
    border: 1px solid #e0d7c6;
    border-radius: 8px 8px 0 0;
    background: #fffbf5;
    cursor: pointer;
    font-size: 0.95rem;
    color: #5c4a3a;
    margin: 0 3px;
    border-bottom: none;
    transition: flex-basis 0.3s ease, padding 0.3s;
    white-space: nowrap;
    flex: 0 1 auto;
    will-change: flex-basis;
    min-width: 44px;
    text-align: center;           /* 文字水平居中 */
    overflow: hidden;             /* 隐藏溢出 */
    text-overflow: hidden;
}

.tab-btn:hover { background: #fef3e4; }

.tab-btn.active {
    background: #d97706;
    color: white;
    border-color: #d97706;
    font-weight: 600;
}

/* dock模式不再用transform，完全由js控制宽度 */
.dock-mode .tab-btn {
    /* 保留占位，不设置额外样式 */
}

.mobile-select {
    display: none;
    width: 100%;
    padding: 8px 12px;
    border: 1px solid #e0d7c6;
    border-radius: 6px;
    background: #fffbf5;
    font-size: 1rem;
    color: #5c4a3a;
    margin-bottom: 8px;
}

/* 卡片滚动区域 */
.cards-scroll {
    flex: 1;
    overflow: visible;
    padding: 0;
    background: transparent;
    min-height: 0;
}

/* 卡片容器 */
.card-container {
    height: 100%;
    display: flex;
    flex-direction: column;
    min-height: 0;
}

.device-card { display: none; width: fit-content; margin: 0; }
.device-card.active {
    display: flex;
    flex-direction: column;
    height: 100%;
    min-height: 0;
}
.card-inner {
    background: #fffdf9;
    border-radius: 0 0 12px 12px;
    box-shadow: 0 2px 12px rgba(0,0,0,0.04);
    border: 1px solid #f0e9db;
    display: flex;
    flex-direction: column;
    height: 100%;
    min-height: 0;
}
.card-header {
    background: #d97706;
    color: white;
    padding: 8px 16px;
    display: flex;
    justify-content: space-between;
    align-items: center;
    flex-shrink: 0;
}
.device-name { font-weight: 600; font-size: 1.1rem; }
.actions { display: flex; align-items: center; gap: 6px; }
.actions button {
    background: rgba(255,255,255,0.2);
    border: none; color: white; border-radius: 6px;
    padding: 4px 10px; font-size: 0.9rem; cursor: pointer;
    transition: 0.2s; display: flex; align-items: center; gap: 4px;
}
.actions button:hover { background: rgba(255,255,255,0.35); }

/* 卡片内容区可滚动 */
.card-body {
    flex: 1;
    overflow-y: auto;
    overflow-x: auto;
    padding: 0;
    scrollbar-width: thin;
    scrollbar-color: #d9d0c1 transparent;
    min-height: 0;
}
.card-body::-webkit-scrollbar { width: 5px; height: 5px; }
.card-body::-webkit-scrollbar-track { background: transparent; }
.card-body::-webkit-scrollbar-thumb { background: #d9d0c1; border-radius: 3px; border: none; }
.card-body::-webkit-scrollbar-button { display: none; }

/* 表格 */
table { border-collapse: collapse; font-size: 0.875rem; width: fit-content; margin: 0 auto; }
th,td { padding: 7px 12px; border-bottom: 1px solid #f0e9db; text-align: left; white-space: nowrap; }
th { background: #fff7ed; font-weight: 600; color: #5c4a3a; position: sticky; top: 0; z-index: 2; }
th .col-check { font-size: 0.8rem; font-weight: normal; display: flex; align-items: center; gap: 4px; }
.group-header { background: #fbf6f0; cursor: pointer; }
.group-header td { font-weight: 600; padding: 8px 12px; color: #5c4a3a; font-size: 0.85rem; }
.group-header td::before { content:"▾ "; margin-right:4px; font-size:0.8rem; color:#b08968; }
.group-header.collapsed td::before { content:"▸ "; }
.data-row td:first-child { padding-left:24px; font-family:"SF Mono","Fira Code",monospace; font-size:0.82rem; color:#1e293b; }
.data-row.diff-row { background:#ffece5; }
.data-row.hover-row { background:#fdf4e3; }
.data-row.diff-row.hover-row { background:#fce0d5; }
.config-cell .cfg-emoji { font-size:1rem; }
.hidden-row { display:none; }

/* 卡片视图（移动端） */
.card-view { display:none; }
.view-cards .table-view { display:none; }
.view-cards .card-view { display:block; }
.card-view .cards-list { display:flex; flex-direction:column; gap:8px; padding:8px; }
.card-view .config-card { background:#fffbf5; border:1px solid #f0e9db; border-radius:8px; overflow:hidden; }
.card-view .config-card .card-title { background:#fef7ed; padding:8px 12px; font-family:monospace; font-size:0.85rem; font-weight:600; border-bottom:1px solid #f0e9db; word-break:break-all; }
.card-view .config-card .card-values { display:flex; flex-direction:column; padding:4px 0; }
.card-view .val-row { display:flex; justify-content:space-between; padding:4px 12px; font-size:0.85rem; align-items:center; }
.card-view .val-tag { font-weight:500; min-width:50px; }
.card-view .config-card.diff-card { background:#ffece5; }
.card-view .config-card.diff-card .card-title { background:#fce0d5; }
.card-view .group-title { font-weight:600; padding:6px 12px; background:#fbf6f0; border-radius:6px; margin:4px 0; cursor:pointer; font-size:0.85rem; display:flex; align-items:center; }
.card-view .group-title::before { content:"▾ "; margin-right:4px; font-size:0.8rem; color:#b08968; }
.card-view .group-title.collapsed::before { content:"▸ "; }

/* 配置标签 */
.cfg-y{background:#e6f7ec;color:#1e6b2e;border:1px solid #b7d7b9; display:inline-block; padding:2px 8px; border-radius:12px; font-size:0.78rem; font-weight:500;}
.cfg-m{background:#eef2ff;color:#1a4e7a;border:1px solid #b8d5f5; display:inline-block; padding:2px 8px; border-radius:12px; font-size:0.78rem; font-weight:500;}
.cfg-notset{background:#f4f4f5;color:#5c6370;border:1px solid #d4d7db; display:inline-block; padding:2px 8px; border-radius:12px; font-size:0.78rem; font-weight:500;}

/* 图例 */
.legend {
    position: fixed; right:20px; top:80px; width:200px;
    background:#fffdf9; border-radius:12px; box-shadow:0 4px 16px rgba(0,0,0,0.06);
    padding:14px; z-index:200; cursor:move; font-size:0.85rem; color:#475569;
    border:1px solid #f0e9db;
}
.legend-title { font-weight:600; margin-bottom:8px; cursor:auto; color:#5c4a3a; }
.legend-item { display:flex; align-items:center; gap:6px; margin:6px 0; }
.legend-dot { width:14px; height:14px; border-radius:4px; border:1px solid rgba(0,0,0,0.1); margin-right:4px; display:inline-block; }

.legend-popup {
    display:none; position:fixed; bottom:20px; left:50%; transform:translateX(-50%);
    background:#fffdf9; padding:16px; border-radius:12px; box-shadow:0 4px 16px rgba(0,0,0,0.08);
    z-index:300; font-size:0.85rem; max-width:90vw; border:1px solid #f0e9db;
}
.legend-popup.active { display:block; }

@media (max-width: 768px) {
    .tab-bar { display: none; }
    .mobile-select { display: block; }
    .legend { display: none; }
}
</style>
</head>
<body>
<div class="main-wrapper">
    <select class="mobile-select" id="mobile-select"></select>
    <div class="tab-bar" id="tab-bar"></div>
    <div class="cards-scroll" id="cards-scroll">
        <div class="card-container" id="card-container"></div>
    </div>
</div>

<div class="legend" id="legend">
    <div class="legend-title">图例</div>
    <div class="legend-item"><span class="legend-dot" style="background:#e6f7ec"></span> ✅ 内建(y)</div>
    <div class="legend-item"><span class="legend-dot" style="background:#eef2ff"></span> 📦 模块(m)</div>
    <div class="legend-item"><span class="legend-dot" style="background:#f4f4f5"></span> ❌ 未设置(not set)</div>
    <div class="legend-item"><span class="legend-dot" style="background:#ffece5"></span> 行高亮 = 有差异</div>
    <div class="legend-item"><span class="legend-dot" style="background:#fdf4e3"></span> 鼠标悬浮行</div>
</div>
<div class="legend-popup" id="legend-popup"></div>

<script>
HTMLEOF

    # 输出预生成的 JS 数据
    printf '%s' "$js_data"

    # 输出剩余的 JS 逻辑
    cat <<'HTMLEOF'

(function() {
    const tabBar = document.getElementById('tab-bar');
    const mobileSelect = document.getElementById('mobile-select');
    const cardContainer = document.getElementById('card-container');
    let activeDevice = null;
    let currentView = window.innerWidth <= 768 ? 'cards' : 'table';
    let fontScale = 1.0;
    let colChecks = {};
    CONFIG_TAGS.forEach(t => colChecks[t] = true);

    // ---------- 工具函数 ----------
    function getEmoji(val) {
        if (val === 'y') return '✅';
        if (val === 'm') return '📦';
        if (val === 'not set') return '❌';
        return '—';
    }
    function escapeId(str) { return CSS.escape(str); }

    // ---------- UI 构建 ----------
    function buildAll() {
        if (DEVICE_ORDER.length === 0) {
            cardContainer.innerHTML = '<p style="text-align:center;padding:20px;">没有设备数据。</p>';
            return;
        }
        mobileSelect.innerHTML = '';
        tabBar.innerHTML = '';
        cardContainer.innerHTML = '';

        DEVICE_ORDER.forEach((dev, idx) => {
            const btn = document.createElement('button');
            btn.className = 'tab-btn';
            btn.textContent = dev.tag;
            btn.dataset.deviceId = dev.id;
            tabBar.appendChild(btn);

            const opt = document.createElement('option');
            opt.value = dev.id;
            opt.textContent = dev.tag;
            mobileSelect.appendChild(opt);

            const cardDiv = document.createElement('div');
            cardDiv.className = 'device-card';
            cardDiv.dataset.deviceId = dev.id;
            cardDiv.innerHTML = buildDeviceCard(dev);
            cardContainer.appendChild(cardDiv);

            if (idx === 0) {
                btn.classList.add('active');
                cardDiv.classList.add('active');
                activeDevice = dev.id;
                mobileSelect.value = dev.id;
            }
        });
        applyView();
        refreshAllInteractions();
        syncTabBarWidth();
        checkDockMode();
    }

    function buildDeviceCard(dev) {
        const groups = DEVICE_ITEMS[dev.id] ? Object.keys(DEVICE_ITEMS[dev.id]) : [];
        if (groups.length === 0) return '';

        let tableRows = '';
        groups.forEach(group => {
            const gid = escapeId((group || '').replace(/\s+/g,'_'));
            const keys = DEVICE_ITEMS[dev.id][group] || [];
            tableRows += `<tr class="group-header" data-group="${gid}"><td colspan="${CONFIG_TAGS.length+1}">📁 ${group}</td></tr>`;
            keys.forEach(key => {
                const item = (DEVICE_DATA[dev.id][group] || []).find(it => it.key === key);
                if (!item) return;
                tableRows += `<tr class="data-row" data-group="${gid}">`;
                tableRows += `<td class="config-key">${key}</td>`;
                CONFIG_TAGS.forEach(tag => {
                    const raw = item.values[tag] || '';
                    tableRows += `<td class="config-cell" data-value="${raw}"><span class="cfg-emoji">${getEmoji(raw)}</span></td>`;
                });
                tableRows += `</tr>`;
            });
        });

        let cardsHtml = '<div class="cards-list">';
        groups.forEach(group => {
            const gid = escapeId((group || '').replace(/\s+/g,'_'));
            const keys = DEVICE_ITEMS[dev.id][group] || [];
            cardsHtml += `<div class="group-title" data-group="${gid}">📁 ${group}</div>`;
            cardsHtml += `<div class="group-items" data-group="${gid}">`;
            keys.forEach(key => {
                const item = (DEVICE_DATA[dev.id][group] || []).find(it => it.key === key);
                if (!item) return;
                cardsHtml += `<div class="config-card" data-group="${gid}" data-key="${key}">`;
                cardsHtml += `<div class="card-title">${key}</div><div class="card-values">`;
                CONFIG_TAGS.forEach(tag => {
                    const raw = item.values[tag] || '';
                    cardsHtml += `<div class="val-row" data-tag="${tag}"><span class="val-tag">${tag}</span><span class="cfg-emoji">${getEmoji(raw)}</span></div>`;
                });
                cardsHtml += `</div></div>`;
            });
            cardsHtml += `</div>`;
        });
        cardsHtml += '</div>';

        return `
            <div class="card-inner">
                <div class="card-header">
                    <span class="device-name">${dev.tag}</span>
                    <div class="actions">
                        <button class="toggle-view-btn" title="切换视图">🔄</button>
                        <button class="zoom-out-btn" title="缩小字体">A⁻</button>
                        <button class="zoom-in-btn" title="放大字体">A⁺</button>
                        <button class="legend-btn-mobile" title="图例">ℹ️</button>
                        <button class="collapse-all-btn" title="全部折叠">折</button>
                        <button class="expand-all-btn" title="全部展开">展</button>
                        <label style="color:white;font-size:0.85rem;display:flex;align-items:center;gap:4px;margin-left:8px;">
                            <input type="checkbox" class="toggle-same" checked> 显示相同行
                        </label>
                    </div>
                </div>
                <div class="card-body">
                    <div class="table-view">
                        <table>
                            <thead><tr>
                                <th>配置项</th>
                                ${CONFIG_TAGS.map(t => `<th><label class="col-check"><input type="checkbox" class="col-cb" data-tag="${t}" checked>${t}</label></th>`).join('')}
                            </tr></thead>
                            <tbody>${tableRows}</tbody>
                        </table>
                    </div>
                    <div class="card-view">${cardsHtml}</div>
                </div>
            </div>`;
    }

    function applyView() {
        document.querySelectorAll('.device-card').forEach(card => {
            card.classList.toggle('view-cards', currentView !== 'table');
        });
    }

    // ---------- 表格/卡片交互 ----------
    function refreshCard(card) {
        if (currentView === 'table') refreshTable(card);
        else refreshCards(card);
    }

    function refreshTable(card) {
        const tbody = card.querySelector('tbody');
        if (!tbody) return;
        const showSame = card.querySelector('.toggle-same')?.checked ?? true;
        tbody.querySelectorAll('.data-row').forEach(row => {
            const cells = row.querySelectorAll('.config-cell');
            if (cells.length < 2) return;
            const vals = Array.from(cells).map(c => c.getAttribute('data-value')||'');
            const hasDiff = vals.some((v,i) => colChecks[CONFIG_TAGS[i]] && v !== vals[0]);
            row.classList.toggle('diff-row', hasDiff);
            const allSame = vals.every(v => v === vals[0]);
            row.classList.toggle('hidden-row', allSame && !showSame);
        });
    }

    function refreshCards(card) {
        const showSame = card.querySelector('.toggle-same')?.checked ?? true;
        card.querySelectorAll('.config-card').forEach(cardEl => {
            const valRows = cardEl.querySelectorAll('.val-row');
            let vals = [];
            valRows.forEach(row => {
                const emoji = row.querySelector('.cfg-emoji').textContent;
                const tag = row.dataset.tag;
                if (emoji==='✅') vals.push({tag,v:'y'});
                else if (emoji==='📦') vals.push({tag,v:'m'});
                else if (emoji==='❌') vals.push({tag,v:'not set'});
                else vals.push({tag,v:''});
            });
            const hasDiff = vals.some(v => colChecks[v.tag] && v.v !== vals[0].v);
            cardEl.classList.toggle('diff-card', hasDiff);
            const allSame = vals.every(v => v.v === vals[0].v);
            cardEl.style.display = (allSame && !showSame) ? 'none' : '';
        });
    }

    function refreshAllInteractions() {
        document.querySelectorAll('.device-card.active').forEach(c => refreshCard(c));
    }

    function setAllGroups(card, collapse) {
        if (currentView === 'table') {
            const headers = card.querySelectorAll('.group-header');
            headers.forEach(h => {
                const group = h.dataset.group;
                const rows = card.querySelectorAll(`.data-row[data-group="${escapeId(group)}"]`);
                if (collapse) {
                    h.classList.add('collapsed');
                    rows.forEach(r => r.classList.add('hidden-row'));
                } else {
                    h.classList.remove('collapsed');
                    rows.forEach(r => r.classList.remove('hidden-row'));
                }
            });
        } else {
            const titles = card.querySelectorAll('.group-title');
            titles.forEach(t => {
                const group = t.dataset.group;
                const items = card.querySelectorAll(`.config-card[data-group="${escapeId(group)}"]`);
                if (collapse) {
                    t.classList.add('collapsed');
                    items.forEach(it => it.style.display = 'none');
                } else {
                    t.classList.remove('collapsed');
                    items.forEach(it => it.style.display = '');
                }
            });
        }
    }

    function switchDevice(id) {
        if (activeDevice === id) return;
        document.querySelectorAll('.tab-btn').forEach(b => b.classList.remove('active'));
        const activeBtn = document.querySelector(`.tab-btn[data-device-id="${escapeId(id)}"]`);
        if (activeBtn) activeBtn.classList.add('active');

        document.querySelectorAll('.device-card').forEach(c => c.classList.remove('active'));
        const card = document.querySelector(`.device-card[data-device-id="${escapeId(id)}"]`);
        if (card) {
            card.classList.add('active');
            refreshCard(card);
        }
        activeDevice = id;
        mobileSelect.value = id;
        syncTabBarWidth();
    }

    // ---------- Dock 模式与弹性动画 ----------
    let dockEnabled = false;
    let savedBasis = new Map();  // 记录每个标签的原始flex-basis

    function checkDockMode() {
        if (window.innerWidth <= 768) {
            tabBar.classList.remove('dock-mode');
            dockEnabled = false;
            resetAllTabs();
            return;
        }

        syncTabBarWidth();   // 先让标签栏宽度等于激活卡片宽度

        const totalWidth = Array.from(tabBar.children).reduce((sum, btn) => sum + btn.scrollWidth, 0);
        const containerWidth = tabBar.clientWidth;

        if (totalWidth > containerWidth && !dockEnabled) {
            // 首次溢出：保存每个标签的原始宽度
            Array.from(tabBar.children).forEach(btn => {
                if (!savedBasis.has(btn)) {
                    savedBasis.set(btn, btn.getBoundingClientRect().width);
                }
            });
            tabBar.classList.add('dock-mode');
            dockEnabled = true;
        } else if (totalWidth <= containerWidth && dockEnabled) {
            resetAllTabs();
            tabBar.classList.remove('dock-mode');
            dockEnabled = false;
        }
    }

    function resetAllTabs() {
        Array.from(tabBar.children).forEach(btn => {
            btn.style.flexBasis = '';
            btn.style.transition = '';
            savedBasis.delete(btn);
        });
    }

    // 弹性动画核心：分配放大增量到相邻标签
    function applyHoverEffect(targetBtn) {
        if (!dockEnabled) return;
        const buttons = Array.from(tabBar.children);
        const idx = buttons.indexOf(targetBtn);
        if (idx === -1) return;

        // 临时解除溢出隐藏并设为 auto 宽度，测量真实文本宽度
        const prevOverflow = targetBtn.style.overflow;
        const prevFlexBasis = targetBtn.style.flexBasis;
        targetBtn.style.overflow = 'visible';
        targetBtn.style.flexBasis = 'auto';
        const idealWidth = targetBtn.scrollWidth + 8;   // 真实文本占宽
        targetBtn.style.overflow = prevOverflow || '';
        targetBtn.style.flexBasis = prevFlexBasis || '';

        const origWidth = savedBasis.get(targetBtn) || targetBtn.getBoundingClientRect().width;
        if (idealWidth <= origWidth) {
            // 无需放大，恢复其他压缩
            clearHoverEffect();
            return;
        }

        const delta = idealWidth - origWidth;

        // 收集相邻待压缩标签（左右各2个）
        const compressCandidates = [];
        for (let dist = 1; dist <= 2; dist++) {
            const left = buttons[idx - dist];
            const right = buttons[idx + dist];
            if (left) compressCandidates.push({ btn: left, dist });
            if (right) compressCandidates.push({ btn: right, dist });
        }
        if (compressCandidates.length === 0) return;

        // 权重：距离1权重2，距离2权重1
        const weightSum = compressCandidates.reduce((s, c) => s + (c.dist === 1 ? 2 : 1), 0);
        const unit = delta / weightSum;

        // 分配宽度
        buttons.forEach((btn, i) => {
            if (i === idx) {
                btn.style.flexBasis = idealWidth + 'px';
            } else {
                const candidate = compressCandidates.find(c => c.btn === btn);
                if (candidate) {
                    const shrink = unit * (candidate.dist === 1 ? 2 : 1);
                    const orig = savedBasis.get(btn) || btn.getBoundingClientRect().width;
                    const newWidth = Math.max(44, orig - shrink);
                    btn.style.flexBasis = newWidth + 'px';
                } else {
                    // 未参与压缩的恢复原始宽度
                    if (savedBasis.has(btn)) {
                        btn.style.flexBasis = savedBasis.get(btn) + 'px';
                    }
                }
            }
            if (!btn.style.transition) {
                btn.style.transition = 'flex-basis 0.3s ease';
            }
        });
    }

    function clearHoverEffect() {
        if (!dockEnabled) return;
        const buttons = Array.from(tabBar.children);
        buttons.forEach(btn => {
            if (savedBasis.has(btn)) {
                btn.style.flexBasis = savedBasis.get(btn) + 'px';
            }
        });
    }

    // ---------- 事件绑定 ----------
    function bindEvents() {
        mobileSelect.addEventListener('change', e => switchDevice(e.target.value));

        // 标签栏点击切换设备
        tabBar.addEventListener('click', e => {
            const btn = e.target.closest('.tab-btn');
            if (!btn) return;
            switchDevice(btn.dataset.deviceId);
        });

        // 卡片内各种交互（原有功能全部保留）
        cardContainer.addEventListener('click', e => {
            const card = e.target.closest('.device-card');
            if (!card) return;

            if (e.target.classList.contains('toggle-same')) {
                refreshCard(card);
            }
            if (e.target.classList.contains('col-cb')) {
                const tag = e.target.dataset.tag;
                colChecks[tag] = e.target.checked;
                document.querySelectorAll(`.col-cb[data-tag="${tag}"]`).forEach(cb => cb.checked = e.target.checked);
                refreshAllInteractions();
            }
            // 分组折叠
            if (e.target.closest('.group-header')) {
                const header = e.target.closest('.group-header');
                const group = header.dataset.group;
                const tbody = header.closest('tbody');
                const rows = tbody.querySelectorAll(`.data-row[data-group="${group}"]`);
                const hidden = rows.length > 0 && rows[0].classList.contains('hidden-row');
                rows.forEach(r => r.classList.toggle('hidden-row', !hidden));
                header.classList.toggle('collapsed', !hidden);
            }
            if (e.target.closest('.group-title')) {
                const header = e.target.closest('.group-title');
                const group = header.dataset.group;
                const items = header.parentElement.querySelectorAll(`.config-card[data-group="${group}"]`);
                const hidden = items.length > 0 && items[0].style.display === 'none';
                items.forEach(it => it.style.display = hidden ? '' : 'none');
                header.classList.toggle('collapsed', !hidden);
            }
            // 全部折叠/展开
            if (e.target.classList.contains('collapse-all-btn')) setAllGroups(card, true);
            if (e.target.classList.contains('expand-all-btn')) setAllGroups(card, false);

            // 视图/字体/图例
            if (e.target.classList.contains('toggle-view-btn')) {
                currentView = currentView === 'table' ? 'cards' : 'table';
                applyView();
                refreshAllInteractions();
            }
            if (e.target.classList.contains('zoom-out-btn')) {
                fontScale = Math.max(0.7, fontScale - 0.1);
                document.documentElement.style.fontSize = fontScale + 'rem';
            }
            if (e.target.classList.contains('zoom-in-btn')) {
                fontScale += 0.1;
                document.documentElement.style.fontSize = fontScale + 'rem';
            }
            if (e.target.classList.contains('legend-btn-mobile')) {
                const popup = document.getElementById('legend-popup');
                popup.innerHTML = document.getElementById('legend').innerHTML;
                popup.classList.toggle('active');
                setTimeout(() => popup.classList.remove('active'), 3000);
            }
        });

        // 鼠标悬浮表格行效果
        cardContainer.addEventListener('mouseover', e => {
            const row = e.target.closest('.data-row');
            if (row && currentView === 'table') row.classList.add('hover-row');
        });
        cardContainer.addEventListener('mouseout', e => {
            const row = e.target.closest('.data-row');
            if (row && currentView === 'table') row.classList.remove('hover-row');
        });

        // ========== Dock 弹性动画事件 ==========
        tabBar.addEventListener('mouseover', e => {
            if (!dockEnabled) return;
            const btn = e.target.closest('.tab-btn');
            if (!btn) return;
            applyHoverEffect(btn);
        });
        tabBar.addEventListener('mouseout', e => {
            if (!dockEnabled) return;
            // 判断是否移出整个标签栏
            if (!e.relatedTarget || !tabBar.contains(e.relatedTarget)) {
                clearHoverEffect();
            }
        });

        // 窗口大小改变时重新评估 dock 模式，并重置动画
        window.addEventListener('resize', () => {
            checkDockMode();
            syncTabBarWidth();
            // 尺寸变化后可能不再溢出，需要清除效果
            if (!dockEnabled) resetAllTabs();
        });
    }

    // ---------- 同步标签栏宽度 ----------
    function syncTabBarWidth() {
        if (window.innerWidth <= 768) return;
        const activeCard = document.querySelector('.device-card.active');
        if (activeCard) {
            tabBar.style.width = activeCard.offsetWidth + 'px';
        }
    }

    // ---------- 启动 ----------
    buildAll();
    bindEvents();
    document.documentElement.style.fontSize = fontScale + 'rem';

    if (window.innerWidth <= 768) {
        currentView = 'cards';
        applyView();
        refreshAllInteractions();
    }
})();
</script>
</body>
</html>
HTMLEOF
} > "$OUTPUT_HTML"

echo "HTML 文件已生成: $OUTPUT_HTML"