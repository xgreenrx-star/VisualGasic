import { readFileSync, writeFileSync, mkdirSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import path from 'node:path';
import { buildOpeningPerformance } from './build_opening_performance.mjs';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../assets/opening_cinematic');
mkdirSync(root, { recursive: true });
const script = JSON.parse(readFileSync(path.join(root, 'script.json'), 'utf8'));
const visualScale = script.visualScale;
let seed = 1986;
const random = () => { seed = (Math.imul(seed, 1664525) + 1013904223) >>> 0; return seed / 4294967296; };
const fmt = n => Number(n.toFixed(2));
const fmtScale = n => Number(n.toFixed(4));
const ringRadiusPx = 566, planetRadiusPx = 249;
const shipSourceWidth = 296, shipSourceLength = 260;
const projectedShipWidth = angle => {
  const radians = angle * Math.PI / 180;
  return Math.cos(radians) * visualScale.ashWingspanM + Math.sin(radians) * visualScale.ashLengthM;
};
const projectedShipArtWidth = angle => {
  const radians = angle * Math.PI / 180;
  return Math.cos(radians) * shipSourceWidth + Math.sin(radians) * shipSourceLength;
};
const arrivalShipWidthPx = ringRadiusPx * 2
  * projectedShipWidth(26) / (visualScale.ringOuterRadiusKm * 2000)
  * (visualScale.arrivalCameraToRingKm * 1000 / visualScale.arrivalCameraToAshM);
const arrivalShipScale = arrivalShipWidthPx / projectedShipArtWidth(26);
const approachOpeningWidthPx = 152;
const approachShipWidthPx = approachOpeningWidthPx
  * projectedShipWidth(42) / visualScale.serviceOpeningClearWidthM;
const approachShipScale = approachShipWidthPx / projectedShipArtWidth(42);
const defs = `<defs>
 <linearGradient id="space" x2=".8" y2="1"><stop stop-color="#02040b"/><stop offset=".6" stop-color="#0b1621"/><stop offset="1" stop-color="#020710"/></linearGradient>
 <linearGradient id="wall" x2="1" y2="1"><stop stop-color="#0e1e27"/><stop offset=".55" stop-color="#111820"/><stop offset="1" stop-color="#03080e"/></linearGradient>
 <linearGradient id="table" x2=".2" y2="1"><stop stop-color="#25383d"/><stop offset=".4" stop-color="#122229"/><stop offset="1" stop-color="#03080e"/></linearGradient>
 <linearGradient id="skin" x1="0" x2="1" y2=".3"><stop stop-color="#c59b72"/><stop offset=".3" stop-color="#8f6c55"/><stop offset=".7" stop-color="#4f443f"/><stop offset="1" stop-color="#192d34"/></linearGradient>
 <linearGradient id="coat" x2=".9" y2="1"><stop stop-color="#31434a"/><stop offset=".45" stop-color="#14252e"/><stop offset="1" stop-color="#050c13"/></linearGradient>
 <radialGradient id="amber"><stop stop-color="#ffbb65" stop-opacity=".45"/><stop offset="1" stop-color="#e78030" stop-opacity="0"/></radialGradient>
 <radialGradient id="cyan"><stop stop-color="#40d5e0" stop-opacity=".25"/><stop offset="1" stop-color="#30aac0" stop-opacity="0"/></radialGradient>
 <radialGradient id="planet" cx=".28" cy=".2" r=".86"><stop stop-color="#bca88a"/><stop offset=".4" stop-color="#796b59"/><stop offset=".68" stop-color="#3c3b38"/><stop offset=".86" stop-color="#111a21"/><stop offset="1" stop-color="#040912"/></radialGradient>
 <radialGradient id="shade" cx=".18" cy=".25" r=".8"><stop offset=".5" stop-color="#000" stop-opacity="0"/><stop offset="1" stop-color="#010611" stop-opacity=".95"/></radialGradient>
 <radialGradient id="vignette"><stop offset=".3" stop-color="#000" stop-opacity="0"/><stop offset="1" stop-color="#000" stop-opacity=".68"/></radialGradient>
 <filter id="glow" x="-.5" y="-.5" width="2" height="2"><feGaussianBlur stdDeviation="7"/></filter>
 <filter id="dust"><feTurbulence baseFrequency=".7" numOctaves="3" seed="12" stitchTiles="stitch"/><feColorMatrix type="saturate" values="0"/><feComponentTransfer><feFuncA type="linear" slope=".055"/></feComponentTransfer><feBlend in="SourceGraphic" mode="soft-light"/></filter>
 <filter id="rock"><feTurbulence type="fractalNoise" baseFrequency=".012 .026" numOctaves="5" seed="43"/><feColorMatrix type="saturate" values="0"/><feBlend in="SourceGraphic" mode="multiply"/></filter>
 <clipPath id="disc"><circle cx="850" cy="425" r="${planetRadiusPx}"/></clipPath>
 </defs>`;
const svg = content => `<svg xmlns="http://www.w3.org/2000/svg" width="1600" height="900" viewBox="0 0 1600 900">${defs}${content}<rect width="1600" height="900" fill="url(#vignette)" pointer-events="none"/></svg>\n`;
const stars = () => Array.from({ length: 520 }, () => {
  const x = fmt(random() * 1600), y = fmt(random() * 900);
  return `<circle cx="${x}" cy="${y}" r="${fmt(.25 + random() * .95)}" fill="${random() > .8 ? '#d9bc97' : '#9dbacb'}" opacity="${fmt(.2 + random() * .55)}"/>`;
}).join('');
const ship = (x, y, scale = 1, angle = 0) => `<g transform="translate(${x} ${y}) rotate(${angle}) scale(${scale})">
 <path d="M-78 35L-100 150L-62 57M78 35L100 150L62 57" fill="#ec9947" opacity=".22" filter="url(#glow)"/>
 <path d="M0-110L42-20L148 18L146 44L40 29L31 73L-31 73L-40 29L-146 44L-148 18L-42-20Z" fill="#192c38" stroke="#688592" stroke-width="2"/>
 <path d="M0-110L0 67L-31 73L-42-20Z" fill="#314956"/>
 <path d="M0-88L17-40L0-17L-17-40Z" fill="#92d5db" opacity=".7"/>
 <path d="M-42-20L-146 35M42-20L146 35M-20 1L-25 56M20 1L25 56" stroke="#68abb7" fill="none" stroke-width="2"/>
 <path d="M0 10L0 61L11 48Z" fill="#557582"/>
 <rect x="-84" y="25" width="20" height="53" rx="3" fill="#303941" stroke="#a98158"/>
 <rect x="64" y="25" width="20" height="53" rx="3" fill="#303941" stroke="#a98158"/>
 <path d="M-81 78H-66M66 78H81" stroke="#ffc37b" stroke-width="5"/>
 <path d="M-119 26L-91 19M91 19L119 26" stroke="#18242b" stroke-width="5"/>
 </g>`;
function table() {
  let background = `<rect width="1600" height="900" fill="url(#wall)"/>
  <ellipse cx="1130" cy="210" rx="620" ry="410" fill="url(#cyan)"/>
  <ellipse cx="700" cy="360" rx="460" ry="450" fill="url(#amber)"/>
  <path d="M0 145H1600M0 157H1600M1100 157V620M1370 157V670" fill="none" stroke="#36515c" stroke-width="8"/>
  <path d="M20 152H465M1005 152H1575" stroke="#55c9d1" stroke-width="3"/>
  <path d="M46 190L220 190L220 500L46 500ZM250 190H445V500H250" fill="#020a12" stroke="#2b4856" stroke-width="7"/>`;
  for (let i = 0; i < 13; i++) background += `<path d="M${55 + i * 31} 190V500" stroke="#22515e" opacity=".35"/>`;
  background += `<text x="74" y="244" fill="#5b7f8e" font-family="monospace" font-size="17" letter-spacing="5">DOCK / 07</text>
  <path d="M55 400L410 280" stroke="#5bc7d7" opacity=".16" stroke-width="23"/>
  <path d="M1110 258H1550V510H1110Z" fill="#10171c" stroke="#34464b" stroke-width="5"/>
  <path d="M1120 355H1550M1120 454H1550" stroke="#52605b" stroke-width="6"/>`;
  for (let i = 0; i < 17; i++) {
    const x = 1130 + i * 24;
    background += `<path d="M${x} 348V${285 + i % 3 * 7}h12v${63 - i % 3 * 7}M${x} 448V${379 + i % 4 * 8}h12v${69 - i % 4 * 8}" fill="${['#42534c','#5d4b37','#314b53'][i % 3]}" stroke="#6b7366" stroke-width="1"/>`;
  }
  background += `<path d="M526 80H1000L930 170H584Z" fill="#111a20" stroke="#394850" stroke-width="4"/><path d="M600 163H914" stroke="#ffca7e" stroke-width="6"/><path d="M760 0V80" stroke="#1b262f" stroke-width="12"/>
  <g opacity=".55"><path d="M1250 571Q1232 470 1260 439Q1300 417 1325 455L1353 576" fill="#010810"/><circle cx="1285" cy="429" r="29" fill="#0b1219"/></g>
  <path d="M513 620Q507 499 616 480L695 460L911 474Q1000 500 1028 647" fill="url(#coat)" stroke="#4b6269" stroke-width="3"/>
  <path d="M655 471L729 544L762 501L786 548L881 476L858 553L815 647H687L626 549Z" fill="#192832" stroke="#40515a" stroke-width="3"/>
  <path d="M731 423L724 482Q756 516 787 478L791 423" fill="url(#skin)"/>
  <path d="M674 283L688 239L737 211L790 221L824 257L829 335L808 405L773 450L728 445L693 407L677 347Z" fill="url(#skin)" stroke="#3b3e3b" stroke-width="3"/>
  <path d="M674 306L659 284L668 245L693 231L694 214L730 201L762 211L787 208L816 230L834 272L825 303L806 266L784 263L762 239L725 249L701 269L695 308" fill="#19252c"/>
  <path d="M669 267L690 242M701 231L730 216M772 223L802 241M816 265L824 280" stroke="#71817b" stroke-width="4"/>
  <path d="M697 321L722 312L742 319M775 317L800 309L815 317" fill="none" stroke="#2b2c2a" stroke-width="6"/>
  <path d="M703 332L735 333M777 330L802 328" stroke="#c3a68a" stroke-width="3"/>
  <path d="M706 331L726 330M781 328L796 327" stroke="#101c23" stroke-width="4"/>
  <path d="M752 328L746 370L760 375L773 369" fill="none" stroke="#423c35" stroke-width="4"/>
  <path d="M725 399L754 395L782 391M732 405L761 410" fill="none" stroke="#352e2b" stroke-width="3"/>
  <path d="M697 368L707 394M797 365L786 381M709 348L727 351M781 345L800 342" stroke="#574b3e" stroke-width="2"/>
  <path d="M691 386L729 433L773 441L803 406" fill="none" stroke="#737367" stroke-width="8" opacity=".4"/>
  <path d="M599 534L572 615L689 665L714 622L643 585M902 538L951 620L838 674L806 625L865 585" fill="url(#coat)" stroke="#47606a" stroke-width="3"/>
  <path d="M0 700L825 561L1600 689V900H0Z" fill="url(#table)" stroke="#56707a" stroke-width="3"/>
  <path d="M0 721L825 582L1600 711" fill="none" stroke="#51c5d0" stroke-width="2" opacity=".7"/>
  <path d="M0 734L825 595L1600 724" fill="none" stroke="#236571" stroke-width="8" opacity=".2"/>
  <ellipse cx="656" cy="639" rx="90" ry="15" fill="#02070c" opacity=".55"/>
  <ellipse cx="885" cy="644" rx="82" ry="14" fill="#02070c" opacity=".55"/>
  <path d="M599 534Q575 567 573 606L672 651L694 615L626 580L641 550" fill="url(#coat)" stroke="#47606a" stroke-width="3"/>
  <path d="M902 538Q937 574 947 613L855 654L834 622L887 585L865 552" fill="url(#coat)" stroke="#47606a" stroke-width="3"/>
  <path d="M667 611Q690 600 709 620L739 638L759 641L767 652L744 662L716 651L680 647Z" fill="url(#skin)" stroke="#564c43" stroke-width="2"/>
  <path d="M854 624L827 635L799 641L784 657L795 668L820 654L847 657L866 643" fill="url(#skin)" stroke="#564c43" stroke-width="2"/>
  <path d="M987 542L977 627L1031 647L1041 543Z" fill="#67817c" fill-opacity=".12" stroke="#91aaa1" stroke-width="3"/>
  <path d="M982 597L1035 609L1031 640L979 624Z" fill="#b87936" opacity=".5"/><path d="M983 550L1038 562" stroke="#d7bb8f" opacity=".7" stroke-width="2"/>
  <g transform="translate(825 689) rotate(9)"><rect width="108" height="57" rx="5" fill="#101e26" stroke="#8bbec2" stroke-width="2"/><path d="M14 16H86M14 24H72M14 32H89" stroke="#71e0dd" stroke-width="2"/><circle cx="94" cy="44" r="3" fill="#edb85f"/></g>`;
  for (let i = 0; i < 5; i++) {
    background += `<g transform="translate(${435 + i * 52} ${735 - i * 7}) rotate(${i * 6 - 20})"><rect width="74" height="108" rx="5" fill="#d1ccaf" stroke="#e9dcc0" stroke-width="2"/><path d="M12 12L19 24L12 36L5 24Z" fill="${i % 2 ? '#ad4b35' : '#1a3b46'}"/><path d="M37 38L52 58L37 78L22 58Z" fill="${i % 2 ? '#ad4b35' : '#1a3b46'}"/></g>`;
  }
  background += `<path d="M0 900V440Q34 358 114 397L175 455L216 586L250 675L197 710L140 666L182 900Z" fill="#07121c" stroke="#345965" stroke-width="4"/>
  <ellipse cx="286" cy="756" rx="134" ry="28" fill="#02060b" opacity=".65"/>
  <path d="M169 624Q210 635 229 675L342 719L321 770L204 733Q162 701 157 660Z" fill="url(#coat)" stroke="#345965" stroke-width="4"/>
  <path d="M334 723L365 716L403 721L425 736L414 749L384 742L359 756L325 762Z" fill="url(#skin)" stroke="#7b7566" stroke-width="2"/>
  <path d="M34 475L104 506L161 624M183 660L217 704L317 744" fill="none" stroke="#4eacba" stroke-width="3"/>
  <rect width="1600" height="900" fill="transparent" filter="url(#dust)"/>`;
  return svg(background);
}
function station() {
  let s = `<rect width="1600" height="900" fill="url(#space)"/>${stars()}
  <ellipse cx="1190" cy="340" rx="600" ry="480" fill="url(#cyan)"/>
  <circle cx="1320" cy="210" r="65" fill="#eed7a8" opacity=".08" filter="url(#glow)"/>
  <path d="M170 0H830L1062 208L1097 577L876 838L210 900L0 668V183Z" fill="#080f18" stroke="#2b414e" stroke-width="4"/>
  <path d="M245 87H779L965 248L986 541L800 750L251 798L85 614V249Z" fill="#172833" stroke="#69828b" stroke-width="5"/>
  <path d="M245 87L333 210H716L779 87M965 248L817 307L716 210M986 541L834 502L817 307M800 750L734 609L834 502M251 798L337 640L734 609M85 614L243 523L337 640M85 249L245 87L333 210L243 320L243 523" fill="none" stroke="#415e69" stroke-width="9"/>
  <path d="M340 229H697L803 321V493L727 588H350L265 507V331Z" fill="#020710" stroke="#759ba4" stroke-width="5"/>
  <path d="M350 251H683L778 332V482L712 561H362L289 493V344Z" fill="#0a1823" stroke="#31525f" stroke-width="13"/>
  <path d="M384 291H659L734 352V466L692 520H388L331 476V366Z" fill="#02050a"/>
  <path d="M289 344L331 366M289 493L331 476M683 251L659 291M778 482L734 466" stroke="#f9be70" stroke-width="7"/>
  <path d="M337 640L350 507H712L734 609Z" fill="#213540"/>
  <path d="M374 622L383 521M435 618L440 521M502 615V521M570 613V521M636 610L631 521M699 606L690 521" stroke="#5b909d" stroke-width="2"/>
  <path d="M432 799V900M744 754L776 900M1044 425L1370 424L1413 444L1086 449" stroke="#526e7b" stroke-width="22"/>
  <path d="M1088 422H1358" stroke="#72cbd7" stroke-width="3"/>
  <path d="M1370 399L1438 399L1468 427L1438 457L1370 457Z" fill="#223743" stroke="#708f99" stroke-width="3"/>`;
  for (let i = 0; i < 34; i++) {
    s += `<path d="M${280 + i * 14} ${115 + (i % 2) * 5}v17M${223 + i * 16} ${710 + (i % 2) * 8}v12" stroke="${i % 5 === 0 ? '#e5b46d' : '#608c99'}" stroke-width="4" opacity=".65"/>`;
  }
  s += `<text x="366" y="198" font-family="monospace" font-size="22" letter-spacing="9" fill="#b0bdba">DEPARTURES / 07</text>
  <path d="M95 250L245 87M800 750L985 540" stroke="#63d0d5" stroke-width="3"/>
  ${ship(1088, 661, .86, 38)}
  ${ship(1330, 265, .12, 38)}
  <path d="M1200 800L1550 857" stroke="#e6ab65" stroke-width="1" opacity=".15"/>`;
  return svg(s);
}
function ringBand(front) {
  let out = '';
  const cx = 850, cy = 445, rx = ringRadiusPx, ry = 172, height = 44;
  for (let i = 0; i < 160; i++) {
    const a = i / 160 * Math.PI * 2, b = (i + 1) / 160 * Math.PI * 2;
    if ((Math.sin((a + b) / 2) >= 0) !== front) continue;
    const x1 = cx + Math.cos(a) * rx, y1 = cy + Math.sin(a) * ry;
    const x2 = cx + Math.cos(b) * rx, y2 = cy + Math.sin(b) * ry;
    const light = Math.max(0, .6 - Math.cos(a) * .2 - Math.sin(a) * .3);
    const value = Math.round(14 + light * 35 + (i % 5) * 2);
    const color = `rgb(${value-7},${value+3},${value+11})`;
    out += `<path d="M${fmt(x1)} ${fmt(y1)}L${fmt(x2)} ${fmt(y2)}V${fmt(y2 + height)}L${fmt(x1)} ${fmt(y1 + height)}Z" fill="${color}" stroke="#070f18" stroke-width="1.2"/>`;
    const ix1 = cx + Math.cos(a) * (rx - 14), iy1 = cy + Math.sin(a) * (ry - 5);
    const ix2 = cx + Math.cos(b) * (rx - 14), iy2 = cy + Math.sin(b) * (ry - 5);
    out += `<path d="M${fmt(x1)} ${fmt(y1)}L${fmt(x2)} ${fmt(y2)}L${fmt(ix2)} ${fmt(iy2)}L${fmt(ix1)} ${fmt(iy1)}Z" fill="#45606b" opacity=".8"/>`;
    if (i % 7 !== 0) out += `<path d="M${fmt(x1)} ${fmt(y1 + 10)}L${fmt(x2)} ${fmt(y2 + 10)}" stroke="${i % 9 === 0 ? '#d8a56a' : '#529da9'}" stroke-width="2"/>`;
    if (i % 8 === 0) out += `<path d="M${fmt(x1)} ${fmt(y1-5)}V${fmt(y1+height+6)}" stroke="#82929a" stroke-width="4"/>`;
  }
  return out;
}
function arrival() {
  let s = `<rect width="1600" height="900" fill="url(#space)"/>${stars()}
  <ellipse cx="1170" cy="220" rx="700" ry="450" fill="url(#cyan)" opacity=".55"/>
  ${ringBand(false)}
  <circle cx="850" cy="425" r="${planetRadiusPx + 2}" fill="#9d8b67" opacity=".25" filter="url(#glow)"/>
  <circle cx="850" cy="425" r="${planetRadiusPx}" fill="url(#planet)"/>
  <g clip-path="url(#disc)" opacity=".5"><rect x="598" y="171" width="505" height="505" fill="#c2ab81" filter="url(#rock)"/>
  <path d="M610 319Q741 360 755 460T1004 571M687 224Q793 334 849 354T1094 479M650 433Q760 405 798 505T987 634" fill="none" stroke="#705a43" stroke-width="8" opacity=".4"/></g>
  <circle cx="850" cy="425" r="${planetRadiusPx}" fill="url(#shade)"/>
  ${ringBand(true)}
  <path d="M1305 509L1330 478L1353 486L1365 520L1340 547Z" fill="#283f4b" stroke="#77939b" stroke-width="2"/>
  <path d="M1324 501L1344 508" stroke="#ffbd6d" stroke-width="3"/>
  ${ship(382, 704, fmtScale(arrivalShipScale), 26)}
  <circle cx="143" cy="187" r="35" fill="#f3bc75" opacity=".09" filter="url(#glow)"/>
  <path d="M107 187H179M143 152V222" stroke="#f3bc75" opacity=".25"/>
  <circle cx="143" cy="187" r="2" fill="#ffe1b3"/>`;
  return svg(s);
}
function approach() {
  let s = `<rect width="1600" height="900" fill="url(#space)"/>${stars()}
  <path d="M-100 900L-100 480Q300 150 1700 80V900Z" fill="#101c25" stroke="#3d5965" stroke-width="4"/>
  <path d="M-100 480Q300 150 1700 80L1700 110Q400 180-100 520Z" fill="#385460"/>
  <path d="M-100 500Q300 170 1700 95" stroke="#56a8b6" fill="none" stroke-width="3"/>`;
  for (let i = 0; i < 19; i++) {
    const x = i * 110 - 150;
    s += `<path d="M${x} 365L${x+190} 900" stroke="#213944" stroke-width="5"/>
    <path d="M${x+25} 470L${x+42} 510L${x+91} 510M${x+68} 620L${x+98} 699L${x+135} 699" stroke="#36555e" fill="none" stroke-width="2"/>`;
  }
  s += `<path d="M0 773L1600 415V630L0 1000Z" fill="#060d16" stroke="#48606b" stroke-width="4"/>
  <path d="M0 805L1600 444M0 829L1600 469" stroke="#58b9c3" stroke-width="3"/>
  <path d="M0 849L1600 489" stroke="#1e3c49" stroke-width="12"/>
  <path d="M1036 219L1233 186L1380 590L1142 654L1008 400Z" fill="#1c303c" stroke="#77929b" stroke-width="4"/>
  <path d="M1083 280L1195 254L1292 545L1167 582Z" fill="#01060d" stroke="#55747e" stroke-width="13"/>
  <path d="M1103 302L1177 285L1255 524L1182 544Z" fill="#132c35"/>
  <path d="M1114 337L1184 321M1141 420L1212 401M1164 492L1238 473" stroke="#d0a76e" stroke-width="4"/>
  <path d="M1036 219L1007 148L1213 114L1233 186Z" fill="#29414b" stroke="#607d88" stroke-width="3"/>
  <path d="M1040 191L1214 160" stroke="#4dd8e1" stroke-width="4"/>
  <path d="M1056 236L1065 271M1215 206L1230 243" stroke="#e9b568" stroke-width="6"/>
  <path d="M987 356L785 471L805 512L1008 400" fill="#203742" stroke="#66858d" stroke-width="3"/>
  <path d="M795 482L977 377" stroke="#65a8b3" stroke-width="2"/>
  <path d="M239 492L297 474L416 825L342 848Z" fill="#11222d" stroke="#45626f" stroke-width="3"/>
  <path d="M239 492L229 436L280 420L297 474Z" fill="#2c4550" stroke="#698c97" stroke-width="3"/>
  <path d="M240 449L277 437" stroke="#f0b970" stroke-width="4"/>
  ${ship(775, 612, fmtScale(approachShipScale), 42)}
  <path d="M630 758L955 393" stroke="#50b9c7" stroke-width="2" stroke-dasharray="14 22" opacity=".28"/>
  <path d="M0 0H1600V125Q700 190 0 390Z" fill="#040a12" opacity=".25"/>
  <ellipse cx="1192" cy="391" rx="240" ry="300" fill="url(#cyan)" opacity=".45"/>`;
  return svg(s);
}
for (const [name, content] of [['table',table()], ['station',station()], ['arrival',arrival()], ['approach',approach()]]) {
  writeFileSync(path.join(root, `${name}.svg`), content);
}
if (!process.argv.includes('--art-only')) {
  const voices = JSON.parse(readFileSync(path.join(root, 'voices.json'), 'utf8'));
  let nominal = 0, actual = 0;
  const lines = [];
  const shots = script.shots.map(shot => {
    const assigned = script.lines.filter(line => line.shot === shot.id);
    let duration = shot.duration;
    let previousEnd = 0;
    for (const line of assigned) {
      const voice = voices.find(voice => voice.id === line.id);
      if (!voice || voice.text !== line.text || voice.speaker !== line.speaker || voice.profile !== line.profile
        || voice.speed !== line.speed || voice.silence !== line.silence) {
        throw new Error(`Missing or stale voice for line ${line.id}; re-bake before building.`);
      }
      const local = Math.max(line.at - nominal, previousEnd);
      previousEnd = local + voice.seconds + line.gap;
      duration = Math.max(duration, previousEnd);
      const source = 'data:audio/ogg;base64,' + readFileSync(path.join(root, voice.audio)).toString('base64');
      lines.push({ ...line, ...voice, at: fmt(actual + local), source });
    }
    const result = { ...shot, at: fmt(actual), duration: fmt(duration) };
    nominal += shot.duration;
    actual += duration;
    return result;
  });
  const review = { ...script, shots, lines, duration: fmt(actual), markVoice: 'Temporary am_michael audition; also used by Rob. Recast Mark distinctly before production.' };
  const timeline = { ...review, lines: lines.map(({ source, ...line }) => line) };
  writeFileSync(path.join(root, 'timeline.json'), JSON.stringify(timeline, null, 2) + '\n');
  buildOpeningPerformance(root, timeline);
  writeFileSync(path.join(root, 'review-data.js'), `globalThis.OPENING_REVIEW = ${JSON.stringify(review, null, 2)};\n`);
  console.log(`BUILT: ${shots.length} shots / ${lines.length} neural lines / ${fmt(actual)} seconds / four SVG keyframes`);
} else {
  console.log('BUILT: four original SVG keyframes; voice/timing assembly deferred.');
}
