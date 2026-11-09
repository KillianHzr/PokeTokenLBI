<div align="center">

<img src="assets/icon.png" width="128" alt="PokeTokenBar 아이콘">

# PokeTokenBar

**당신의 AI 코딩 토큰을 포켓몬으로 — 메뉴바에서.**

[![Release](https://img.shields.io/github/v/release/chattymin/PokeTokenBar?color=444d56&label=release)](https://github.com/chattymin/PokeTokenBar/releases)
[![macOS](https://img.shields.io/badge/macOS-14%2B-0969da)](https://www.apple.com/macos/)
[![Swift](https://img.shields.io/badge/Swift-6-f05138)](https://swift.org)
[![Homebrew](https://img.shields.io/badge/Homebrew-cask-8957e5)](#homebrew)
[![License](https://img.shields.io/badge/license-MIT-3fb950)](LICENSE)
[![Sponsor](https://img.shields.io/badge/Sponsor-%E2%99%A5-ea4aaa?logo=githubsponsors&logoColor=white)](https://github.com/sponsors/chattymin)

<a href="https://trendshift.io/repositories/84522?utm_source=repository-badge&amp;utm_medium=badge&amp;utm_campaign=badge-repository-84522" target="_blank" rel="noopener noreferrer"><img src="https://trendshift.io/api/badge/repositories/84522" alt="chattymin%2FPokeTokenBar | Trendshift" width="250" height="55"/></a>
<a href="https://trendshift.io/repositories/84522?utm_source=trendshift-badge&amp;utm_medium=badge&amp;utm_campaign=badge-trendshift-84522" target="_blank" rel="noopener noreferrer"><img src="https://trendshift.io/api/badge/trendshift/repositories/84522/daily?language=Swift" alt="chattymin%2FPokeTokenBar | Trendshift" width="250" height="55"/></a>


[English](README.md) · **한국어** · [日本語](README.ja.md)

</div>

PokeTokenBar는 당신이 이미 태우고 있는 AI 코딩 토큰(Claude Code · Codex · Gemini CLI · Antigravity · OpenCode · Hermes Agent · Cursor · Grok CLI · Copilot CLI · Kiro CLI · Pi Agent · omp · omo · Aside · Kimi Code · Devin CLI)을 macOS 메뉴바 속 자라나는 **포켓몬 companion**으로 바꿔줍니다. 토큰을 쓰면 알이 부화하고, 실제 진화 라인을 따라 진화하며, 최종 진화 후 도감에 졸업하고, 다시 새 알이 시작됩니다. companion 아래에는 정확한 사용량 트래커가 있습니다 — 오늘의 사용량·비용, 공식 5시간/주간 한도를 로컬 로그에서 직접 읽습니다.

> 토큰 사용량은 로컬 Claude Code·Codex·Gemini CLI·Antigravity·OpenCode·Hermes Agent·Cursor·Grok CLI·Copilot CLI·Kiro CLI·Pi Agent·omp·omo·Aside·Kimi Code·Devin CLI 데이터에서 직접 읽습니다(`totalTokens` = input + output + cache, 로컬 날짜) — 외부 CLI 불필요. 비공식·비상업 포켓몬 팬 프로젝트 — [라이선스 & 면책](#라이선스--면책) 참고.

## 왜

- **열어보는 게 즐거운 사용량 트래커.** 사용량이 포켓몬을 키웁니다 — 부화하고, 진화하고, 졸업해 도감을 채우죠. 이로치 한 마리가 다시 열어볼 이유가 됩니다.
- 오늘의 토큰 사용량과 비용을 한눈에 — 대시보드도, 브라우저 탭도 필요 없이.
- 공식 **5시간 / 주간** 한도를 리셋 카운트다운과 함께 추적하고, 현재 burn rate로 언제 도달할지 예측합니다.

<div align="center">
<img src="assets/screenshot-home.png" width="420" alt="팝오버 홈 — 포켓몬, 오늘 토큰, 일별 차트">
</div>

## 어떻게 자라나요

1. 🥚 **평소처럼 코딩하세요.** Claude Code·Codex·Gemini CLI·Antigravity·OpenCode·Hermes Agent·Cursor·Grok CLI·Copilot CLI·Kiro CLI·Pi Agent·omp·omo·Aside·Kimi Code·Devin CLI에서 태우는 토큰이 알을 품습니다 — 따로 돌릴 건 없어요.
2. 🐣 **부화.** [PokéAPI](https://pokeapi.co/)의 **1~9세대 모든 진화 계보(시작점 541종)**에서 공식 capture rate 가중으로 태어납니다 — 흔한 포켓몬은 자주, 전설은 부화 약 220번에 1번. 부화한 포켓몬은 키우는 동안에도 **도감**에 바로 나타납니다. 부화마다 25종 성격 중 하나가 정해지고 — **아주 특별한 우연으론 ✨ 이로치가 태어납니다**.
3. ⚡ **진화.** 계속 코딩하면 실제 진화 트리(1/2/3단, 분기)를 따라 자라고, 단계마다 작은 연출이 반겨줍니다.
4. 🎓 **졸업 & 수집.** 최종 진화 + 임계 도달 시 **도감**에 영구 보존됩니다. 희귀할수록 오래 걸리고(하루 약 2억 5천만 토큰 기준 common ≈7시간, legendary ≈2.4일), 새 알이 도착합니다. 홈에서 지금 속도로 다음 단계까지 남은 시간을 보여 주고, 도감은 포켓몬마다 육성 기록(부화, 졸업, 도구별 토큰, 주 모델, 사탕, 비용)을 남깁니다.
5. 🍬 **쓰는 만큼 사탕 받기.** 5시간·주간 사용량 한도가 차는 만큼 **이상한 사탕**을 받아요. 어떤 요금제든 같은 속도이고, 한도마다 이번 창에서 받은 사탕을 보여 줘요. 한도가 없는 도구(Cursor, Gemini CLI 등)는 6,500만 토큰마다 하나를 줘요. **가방** 탭에서 써서 현재 포켓몬을 키우세요.
6. 🛒 **상점에서 쓰기.** 그동안 사용한 토큰이 곧 재화입니다. **상점** 탭에서 **이상한 사탕**, 이로치 확률을 영구히 올리는 **이로치 부적**, 또는 **가방**에 두었다가 원할 때 지금 포켓몬과 바꾸는 알을 살 수 있어요. 알은 세 종류이고 알마다 확률을 보여 줘요: 일반 **포켓몬 알**, 고급 이상이 확정으로 나오는 **고급 알**, 희귀 이상이 확정으로 나오는 **희귀 알**. 필요한 포켓몬을 도감에 등록하면 **진화의 돌**, **전설의 유물**, **체육관 배지**를 **트레이너** 탭의 **업적**에서 무료로 받을 수 있어요.

## 둘러보기

<table>
<tr>
<td width="45%" align="center"><img src="assets/floating-pet.gif" width="340" alt="바탕화면 플로팅 펫 — 호버 콜아웃과 우클릭 메뉴"></td>
<td width="55%" valign="middle">
<h3>🐾 바탕화면에 두기</h3>
파트너를 메뉴바 밖 바탕화면으로 꺼내 48~384px 원하는 크기로 둘 수 있어요. 호버하면 오늘 사용량, 클릭하면 팝오버, 우클릭하면 메뉴, 드래그로 위치 이동 — 한도 알림은 펫 위 말풍선으로도 떠요.
</td>
</tr>
<tr>
<td width="55%" valign="middle">
<h3>메뉴바 속 파트너</h3>
움직이는 스프라이트가 오늘 토큰 합계(compact, 예: <code>200.7M</code>) 옆에 삽니다. 오늘 비용(<code>$</code>)이나 공식 한도 <code>%</code> 를 더하거나 — 전부 꺼서 캐릭터만 남길 수도 있어요.
</td>
<td width="45%" align="center"><img src="assets/menubar.gif" width="240" alt="메뉴바"></td>
</tr>
<tr>
<td width="45%" align="center"><img src="assets/shiny-banner.gif" width="340" alt="일반 vs 이로치"></td>
<td width="55%" valign="middle">
<h3>✨ 아주 드문 우연, 이로치</h3>
이로치는 메뉴바·홈 카드·진화 라인에서 전용 색으로 표시되고 진화를 거쳐도 유지됩니다. 도감 격자에서도 이로치로 보유한 종을 이로치 색과 ✨로 표시하며, 상세에서 보유한 일반·이로치 모습을 전환합니다. 안농의 격자 아이콘은 A를 유지하고 상세에서 문자와 색을 고릅니다. 전용 알림으로 부화 순간을 알려 줍니다.
</td>
</tr>
<tr>
<td width="55%" valign="middle">
<h3>채우고 싶어지는 도감</h3>
<b>도감</b>은 보유한 종을 한 칸으로 접어 4×4 배치로 한 페이지 16칸씩 보여 줍니다. 이름·번호 검색, 희귀도·이로치 필터와 정렬을 지원합니다. 마우스 휠·트랙패드 또는 클릭 영역을 넓힌 화살표로 페이지를 넘기세요. 홈·진화 라인·<b>포획 로그</b>의 수집한 포켓몬을 누르면 상세로 이동하고, 뒤로가기는 보던 도감 페이지나 열었던 로그 행으로 돌아옵니다. 로그에는 개체별 전체 진화 라인·희귀도·성격·획득일이 남습니다.
</td>
<td width="45%" align="center"><img src="assets/screenshot-collection-pokedex-ko.png" width="300" alt="도감 — 종 하나가 한 칸"><br><br><img src="assets/screenshot-collection-catchlog-ko.png" width="300" alt="포획 로그 — 키운 개체 하나가 한 행"></td>
</tr>
<tr>
<td width="45%" align="center"><img src="assets/screenshot-pokemon-forms-ko.png" width="300" alt="로토무 폼 선택기와 폼별 개체"><br><small>샘플 포켓몬으로 실제 UI를 로컬 렌더링한 이미지입니다.</small></td>
<td width="55%" valign="middle">
<h3>같은 종의 다른 모습까지 수집</h3>
로토무 가전, 쉐이미 랜드·스카이폼, 사철록 계절 모습, 안농 문자, 알로라·가라르·히스이·팔데아 리전폼, 비비용 날개 무늬 등 지원하는 모든 폼을 수집합니다. 알은 그 계열에 아직 없는 폼을 먼저 주고, 모두 모으면 다시 아무 폼이나 줘요. 도감에서 수집한 폼 수와 폼별 개체를 보고, 보유한 폼을 메뉴바·플로팅 펫의 대표로 고르세요. 동쪽 깝질무는 동쪽 트리토돈으로 진화하며, 모습은 저장·내보내기에도 유지됩니다. 타입·능력치·특성·기술은 기본형 데이터를 표시합니다.
</td>
</tr>
<tr>
<td width="45%" align="center"><img src="assets/settings-ko.png" width="300" alt="설정"></td>
<td width="55%" valign="middle">
<h3>설정에서 취향대로</h3>
메뉴바 표시 항목, 새로고침 간격(1–15분/수동), 로그인 시 자동 시작, 한도 섹션만 숨기는 Keychain 끄기, 경고/임박 임계값 한도 알림과 포켓몬 이벤트 알림을 설정합니다. <b>한국어/영어/일본어/스페인어/프랑스어/포르투갈어/독일어/러시아어</b> UI를 지원하며 포켓몬·타입·특성·기술 이름은 선택 언어의 번역이 없으면 영어를 사용합니다.
</td>
</tr>
<tr>
<td width="55%" valign="middle">
<h3>🍬 쓰는 만큼 이상한 사탕</h3>
사용량 한도는 다 채우지 않아도 차는 만큼 <b>이상한 사탕</b>을 줍니다. Pro 요금제의 5시간 세션 하나가 1개, 한 주가 5개이고, 더 큰 요금제는 Pro 몇 개 분인지만큼 줍니다(Max 20x 세션은 5%마다, 한 주는 1%마다 1개). 같은 사용량이면 어떤 요금제든 같은 속도로 받고, 요금제는 로그인에서(claude.ai 세션 키 포함) 읽어요. 처음 보는 계정이나 한도는 그때부터 줍니다. 사탕 하나는 100M 경험치로, 일반 계열 하나를 통째로 키우고도 남아요. <b>가방</b> 탭에서 현재 포켓몬에게 써서 키우세요.
</td>
<td width="45%" align="center"><img src="assets/screenshot-bag-ko.png" width="300" alt="가방 속 이상한 사탕과 민트"></td>
</tr>
<tr>
<td width="45%" align="center"><img src="assets/screenshot-shop-ko.png" width="300" alt="토큰 상점 — 민트·이상한 사탕·포켓몬 알·고급 알·이로치 부적·희귀 알"></td>
<td width="55%" valign="middle">
<h3>🛒 사용량으로 돌아가는 상점</h3>
그동안 쓴 토큰이 곧 재화입니다. 수량과 총가격을 보고 소모품 여러 개를 한 번에 구매하세요. <b>이상한 사탕</b>은 현재 포켓몬을 키우고, <b>민트</b>는 성격을 다시 굴립니다. <b>이로치 부적</b>은 이로치 확률을 영구히 올립니다. 알을 사면 현재 포켓몬을 놓아주고 다시 시작합니다 — 일반 <b>포켓몬 알</b>, 고급 이상 확정 <b>고급 알</b>, 희귀 이상 확정 <b>희귀 알</b>을 고를 수 있고 등급 알에도 전설은 섞여 있습니다. 빈 가방에서는 버튼으로 바로 상점에 갈 수 있습니다. 닷새에 한 번꼴로 <b>떠돌이 상인</b>이 찾아와 자정까지 한 종류의 아이템을 상점 가격의 3분의 1에 사 갑니다(상점에 없는 아이템은 정해진 가격, 화석 알은 사지 않아요). 하나 또는 전부 팔면 토큰이 잔액에 들어옵니다. 화살표로 상인과 오박사를 오갈 수 있습니다.
</td>
</tr>
<tr>
<td width="55%" valign="middle">
<h3>📊 공식 한도, 이제 Antigravity 도</h3>
Antigravity 2.0 과 IDE 가 추정치가 아닌 실제 할당량을 보고합니다. Gemini 모델군과 Claude &amp; GPT 모델군이 각각 <b>5시간</b>·<b>주간</b> 버킷과 리셋 카운트다운을 갖고, Claude Code·Codex 와 나란히 표시됩니다. 백그라운드에서는 토큰 파일을 읽고 OAuth 자격증명을 자동 갱신할 수 있습니다. 수동 갱신은 Keychain에 접근할 수 있습니다.
</td>
<td width="45%" align="center"><img src="assets/screenshot-antigravity-limits-ko.png" width="300" alt="Antigravity 공식 한도 — 모델군별 5시간·주간 버킷"></td>
</tr>
<tr>
<td width="45%" align="center"><img src="assets/screenshot-scan-folders-ko.png" width="300" alt="설정 → 고급의 추가 스캔 폴더"></td>
<td width="55%" valign="middle">
<h3>📁 로그가 엉뚱한 데 있다면 직접 지정</h3>
어떤 도구가 세션을 기본 경로 밖에 둔다면 <b>설정 → 고급</b>에서 직접 루트를 추가하세요 — 콤마·줄바꿈 구분, <code>*</code> 와일드카드, 지금 몇 개 폴더가 걸리는지 실시간 표시. 프로바이더마다 목록이 따로라 한 도구의 폴더가 다른 도구의 파서로 넘어가지 않고, 추가한 경로는 기본 경로를 대체하는 게 아니라 더해집니다.
</td>
</tr>
<tr>
<td width="55%" valign="middle">
<h3>🔑 Keychain 없이 공식 한도</h3>
캐시된 한도 토큰이 만료되면 공식 Claude 한도가 갱신을 누를 때까지 멈추고, 그 갱신이 Keychain 암호 팝업을 띄울 수 있었습니다. 대신 <b>설정 → 고급</b>에 <b>claude.ai 세션 키</b>를 붙여넣으세요 — 한도를 claude.ai 에서 바로 읽어 Keychain 을 아예 건드리지 않고, 자동 폴링이 최신 상태를 유지하며, 저장하는 순간 키를 검증합니다.
</td>
<td width="45%" align="center"><img src="assets/screenshot-session-key-ko.png" width="300" alt="설정 → 고급의 claude.ai 세션 키"></td>
</tr>
<tr>
<td width="45%" align="center"><img src="assets/screenshot-model-breakdown-ko.png" width="300" alt="Pi 의 모델별 토큰 내역"></td>
<td width="55%" valign="middle">
<h3>🧮 세션 로그 하나, 모델 여럿</h3>
Pi는 모델 여러 개를 세션 로그 하나로 흘려보낼 수 있습니다. 이제 사용량이 일률적인 "pi" 가 아니라 <b>실제 모델 id</b> 로 귀속되고, 하루에 여러 모델을 썼다면 팝오버가 오늘 토큰을 모델별로 큰 순서대로 풀어 보여줍니다.
</td>
</tr>
<tr>
<td width="45%" align="center"><img src="assets/screenshot-pokemon-profile-ko.png" width="300" alt="포켓몬마다 고유한 프로필"></td>
<td width="55%" valign="middle">
<h3>포켓몬마다 고유한 프로필</h3>
<b>도감</b>에서 종을 열면 개체별 레벨·성별·성격·특성·개체값·계산된 능력치·배운 기술을 확인할 수 있습니다. 종 설명과 특성·기술은 선택 언어로 표시하고, PokéAPI에 번역이 없으면 영어를 사용합니다.
</td>
</tr>
<tr>
<td width="45%" align="center"><img src="assets/screenshot-difficulty-ko.png" width="300" alt="내 페이스에 맞춰 키우기"></td>
<td width="55%" valign="middle">
<h3>모두 같은 성장 속도</h3>
성장 임계값과 상점 가격은 모든 플레이어가 기본표의 10분의 1입니다. 모두 가장 낮게 두고 있던 슬라이더는 없어졌고, 다른 값으로 만든 저장은 넘어올 때 현재 단계의 진행률을 그대로 유지합니다. 이미 졸업시킨 진화 계보에서 다시 부화하면 <b>2배 빠르게</b> 자랍니다. 아이템·배지의 성장 보너스는 더해지고(+25%와 +25%는 +50%), 중복 보너스가 그 합계에 곱해집니다. 홈의 <b>보너스</b> 화면에서 하나씩 볼 수 있습니다. 홈의 부화·성장 막대에 마우스를 올리면 사용량·목표와 진행률을 볼 수 있습니다.
</td>
</tr>
<tr>
<td width="45%" align="center"><img src="assets/screenshot-daily-trend-ko.png" width="300" alt="이번 달 사용량을 하루씩"></td>
<td width="55%" valign="middle">
<h3>이번 달 사용량을 하루씩</h3>
이번 달의 모든 날짜를 고정된 위치에 놓고 미래 날짜는 빈칸으로 둡니다. 이번 달 두 개 이상 도구를 썼다면 일별 막대를 도구별 색으로 쌓고 범례를 표시합니다. 마우스를 올려 해당 날의 합계와 도구별 토큰·비용(비용 표시를 켠 경우)을 확인하세요. 오늘 사용량이 0이어도 주·월 사용 이력과 합계, 돌아보기 버튼은 계속 보입니다.
</td>
</tr>
<tr>
<td width="45%" align="center"><img src="assets/screenshot-quota-alignment-ko.png" width="300" alt="한눈에 읽는 한도"></td>
<td width="55%" valign="middle">
<h3>한눈에 읽는 한도</h3>
리셋 카운트다운에 실제 시각을 함께 표시하고, 모든 한도 행의 강조색 퍼센트를 오른쪽 끝에 정렬합니다. 설정에서 사용량·남은량을 고르면 숫자와 그래프가 모두 같은 기준으로 바뀝니다.
</td>
</tr>
</table>

## 수집 아이템

각 수집 아이템은 필요한 포켓몬을 도감에 등록하기 전까지 **잠겨** 있어요. 졸업시킨 포켓몬과 놓아준 포켓몬, 그리고 지금 키우는 포켓몬이 이미 도달한 단계가 모두 등록으로 인정돼요. 해금된 아이템은 모두 **트레이너** 탭의 **업적**에서 무료로 받으며, 트레이너 탭에 받을 수 있는 보상 수가 표시돼요. 업적 탭의 잠긴 카드에는 필요한 포켓몬이 표시되고, 아직 등록하지 않은 포켓몬은 회색으로 보여요. 받은 뒤에도 카드에 조건이 작게 남아요.

### 진화의 돌

돌 업적을 받으면 그 돌 **5개**가 다른 소모품과 함께 가방에 들어와요. 하나를 쓰면 지금 포켓몬을 즉시 놓아주고(도감에는 놓아준 기록으로 남아요) 돌의 타입이 확정으로 나오는 새 알을 받아요. 그래서 놓아줄 포켓몬이 있을 때만 쓸 수 있어요. 그 타입으로 이미 다 모은 라인은 돌 알에서 4분의 1 확률로 나오고(일반 알은 절반), 어떤 알도 방금 태어난 라인을 연달아 주지 않아요. 돌 업적은 한 번만 받을 수 있고, 돌은 상점에서 팔지 않아요.

| 돌 | 스프라이트 | 알 타입 | 해금 조건 |
| :--- | :---: | :---: | :--- |
| **리프의돌** | <img src="https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/items/leaf-stone.png" width="28" height="28" alt="리프의돌"> | 풀 | 이상해꽃, 리자몽, 거북왕 |
| **불꽃의돌** | <img src="https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/items/fire-stone.png" width="28" height="28" alt="불꽃의돌"> | 불꽃 | 메가니움, 블레이범, 장크로다일 |
| **물의돌** | <img src="https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/items/water-stone.png" width="28" height="28" alt="물의돌"> | 물 | 나무킹, 번치코, 대짱이 |
| **천둥의돌** | <img src="https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/items/thunder-stone.png" width="28" height="28" alt="천둥의돌"> | 전기 | 토대부기, 초염몽, 엠페르트 |
| **태양의돌** | <img src="https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/items/sun-stone.png" width="28" height="28" alt="태양의돌"> | 에스퍼 | 샤로다, 염무왕, 대검귀 |
| **달의돌** | <img src="https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/items/moon-stone.png" width="28" height="28" alt="달의돌"> | 페어리 | 브리가론, 마폭시, 개굴닌자 |
| **어둠의돌** | <img src="https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/items/dusk-stone.png" width="28" height="28" alt="어둠의돌"> | 악 | 모크나이퍼, 어흥염, 누리레느 |
| **얼음의돌** | <img src="https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/items/ice-stone.png" width="28" height="28" alt="얼음의돌"> | 얼음 | 고릴타, 에이스번, 인텔리레온 |
| **각성의돌** | <img src="https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/items/dawn-stone.png" width="28" height="28" alt="각성의돌"> | 격투 | 마스카나, 라우드본, 웨이니발 |
| **빛의돌** | <img src="https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/items/shiny-stone.png" width="28" height="28" alt="빛의돌"> | 드래곤 | 망나뇽, 보만다, 레쿠쟈 |

앞의 아홉 개 돌은 세대 순서를 따라요: 관동부터 팔데아까지, 돌마다 한 지방의 최종 스타팅 포켓몬 셋을 요구해요.

### 전설의 유물

**트레이너** 탭의 **업적**에서 한 번 받으면 가방에 있는 동안 효과가 계속 적용돼요.

| 유물 | 스프라이트 | 해금 조건 | 효과 |
| :--- | :---: | :--- | :--- |
| **천공의피리** | <img src="https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/items/azure-flute.png" width="28" height="28" alt="천공의피리"> | 같은 전설의 포켓몬을 두 번 졸업 | 전설의 포켓몬이 2배 자주 태어나요 |
| **은빛날개** | <img src="https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/items/silver-wing.png" width="28" height="28" alt="은빛날개"> | 프리져, 썬더, 파이어 | 알 부화에 필요한 토큰이 절반으로 줄어요 |
| **오래된해도** | <img src="https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/items/old-sea-map.png" width="28" height="28" alt="오래된해도"> | 뮤츠, 뮤 | 토큰 사용으로 얻는 성장 +20% |
| **투명한방울** | <img src="https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/items/clear-bell.png" width="28" height="28" alt="투명한방울"> | 라이코, 앤테이, 스이쿤 | 희귀 등급 포켓몬이 25% 더 빨리 성장해요 |
| **무지갯빛날개** | <img src="https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/items/rainbow-wing.png" width="28" height="28" alt="무지갯빛날개"> | 루기아, 칠색조 | 상점의 모든 구매 25% 할인 |
| **화산의돌** | <img src="https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/items/magma-stone.png" width="28" height="28" alt="화산의돌"> | 레지락, 레지아이스, 레지스틸 **또는** 레지에레키, 레지드래고 **또는** 화석 포켓몬 아무거나 4마리¹ **또는** 히드런, 그란돈 | 이미 졸업시킨 라인의 성장 요구량 25% 감소 |
| **마음의물방울** | <img src="https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/items/soul-dew.png" width="28" height="28" alt="마음의물방울"> | 라티아스, 라티오스 | 이상한 사탕 경험치 +50% |
| **초록구슬** | <img src="https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/items/jade-orb.png" width="28" height="28" alt="초록구슬"> | 가이오가, 그란돈, 레쿠쟈 | 알 추가 20% 할인 |
| **그라시데아꽃** | <img src="https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/items/gracidea.png" width="28" height="28" alt="그라시데아꽃"> | 유크시, 엠라이트, 아그놈 | 진화할 포켓몬이 첫 단계에서 25% 빨리 자라요 |
| **백금옥** | <img src="https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/items/griseous-orb.png" width="28" height="28" alt="백금옥"> | 디아루가, 펄기아, 기라티나 | 고스트·드래곤타입 포켓몬이 30% 더 빨리 성장해요 |
| **리버티티켓** | <img src="https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/items/liberty-pass.png" width="28" height="28" alt="리버티티켓"> | 코바르온, 테라키온, 비리디온, 케르디오 중 3마리 | 아직 졸업시킨 적 없는 라인의 성장 요구량 25% 감소 |
| **비추는거울** | <img src="https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/items/reveal-glass.png" width="28" height="28" alt="비추는거울"> | 토네로스, 볼트로스, 랜드로스, 러브로스 중 3마리 | 이로치 확률 2배 (이로치 부적과 중첩) |
| **유전자쐐기** | <img src="https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/items/dna-splicers.png" width="28" height="28" alt="유전자쐐기"> | 레시라무, 제크로무, 큐레무 | 토큰 사용으로 얻는 성장 +50% |
| **지가르데큐브** | <img src="https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/items/zygarde-cube.png" width="28" height="28" alt="지가르데큐브"> | 제르네아스, 이벨타르, 지가르데 | 도감 25종마다 토큰 사용으로 얻는 성장 +1% (최대 +40%) |
| **굴레의항아리** | <img src="https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/items/prison-bottle.png" width="28" height="28" alt="굴레의항아리"> | 디안시, 후파, 볼케니온 | 도감에 없던 모습으로 태어난 포켓몬이 50% 더 빨리 성장해요 |
| **빛나는돌** | <img src="https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/items/sparkling-stone.png" width="28" height="28" alt="빛나는돌"> | 카푸꼬꼬꼭, 카푸나비나, 카푸브루루, 카푸느지느 | 페어리타입 포켓몬이 30% 더 빨리 성장해요 |
| **태양의피리** | <img src="https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/items/sun-flute.png" width="28" height="28" alt="태양의피리"> | 솔가레오, 루나아라, 네크로즈마 | 최종 진화 단계의 포켓몬이 25% 더 빨리 성장해요 |
| **울트라볼** | <img src="https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/items/beast-ball.png" width="28" height="28" alt="울트라볼"> | 울트라비스트 아무거나 4마리² | 울트라비스트가 50% 더 빨리 성장해요 |
| **녹슨검** | <img src="https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/items/rusted-sword.png" width="28" height="28" alt="녹슨검"> | 자시안, 자마젠타, 무한다이노 | 전설의 포켓몬이 25% 더 빨리 성장해요 |
| **유대의고삐** | <img src="https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/items/reins-of-unity.png" width="28" height="28" alt="유대의고삐"> | 블리자포스, 레이스포스, 버드렉스 | 포켓몬이 졸업할 때마다 이상한 사탕 +1 |
| **부스트에너지** | <img src="https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/items/booster-energy.png" width="28" height="28" alt="부스트에너지"> | 패러독스 포켓몬 아무거나 4마리³ | 패러독스 포켓몬이 50% 더 빨리 성장해요 |
| **벽록의가면** | <img src="https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/items/teal-mask.png" width="28" height="28" alt="벽록의가면"> | 오거폰, 조타구, 이야후, 기로치, 복숭악동 중 4마리 | 풀·물·불꽃·바위타입 포켓몬이 20% 더 빨리 성장해요 |
| **테라스탈오브** | <img src="https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/items/tera-orb.png" width="28" height="28" alt="테라스탈오브"> | 코라이돈, 미라이돈, 테라파고스 | 진화의 돌로 받은 알이 2배 빨리 부화해요 |
| **고대의석상** | <img src="https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/items/relic-statue.png" width="28" height="28" alt="고대의석상"> | 레지락, 레지아이스, 레지스틸, 레지기가스, 레지에레키, 레지드래고 | 진화하지 않는 포켓몬이 25% 빨리 자라요 |
| **초승달깃털** | <img src="https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/items/lunar-wing.png" width="28" height="28" alt="초승달깃털"> | 크레세리아, 다크라이 | 에스퍼·악타입 포켓몬이 30% 더 빨리 성장해요 |
| **운석** | <img src="https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/items/meteorite.png" width="28" height="28" alt="운석"> | 지라치, 테오키스 | 토큰 한도를 다 채울 때마다 이상한 사탕 1개 더 |
| **오박사의편지** | <img src="https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/items/oaks-letter.png" width="28" height="28" alt="오박사의편지"> | 세레비, 쉐이미 | 모든 지방의 스타팅 포켓몬이 어느 단계든 25% 빨리 자라요 |
| **바닷물향로** | <img src="https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/items/sea-incense.png" width="28" height="28" alt="바닷물향로"> | 마나피 (피오네가 진화해요), 가이오가 | 등급이 확정된 알(상점, 레전드플레이트)이 2배 빨리 부화해요 |
| **번개카세트** | <img src="https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/items/shock-drive.png" width="28" height="28" alt="번개카세트"> | 비크티니, 메로엣타, 게노세크트 | 이상한 사탕을 쓸 때마다 4번에 1번은 그 사탕이 가방에 남아요 |
| **Z링** | <img src="https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/items/z-ring.png" width="28" height="28" alt="Z링"> | 실버디, 마기아나, 마샤도, 제라오라, 멜메탈 중 4마리 | 강철·전기타입 포켓몬이 30% 더 빨리 성장해요 |
| **악의 족자** | <img src="https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/items/scroll-of-darkness.png" width="28" height="28" alt="악의 족자"> | 우라오스, 자루도 | 격투타입 포켓몬이 30% 더 빨리 성장해요 |
| **고대의항아리** | <img src="https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/items/relic-vase.png" width="28" height="28" alt="고대의항아리"> | 총지엔, 파오젠, 딩루, 위유이 | 중간 진화 단계의 포켓몬이 25% 빨리 자라요 |
| **탐험세트** | <img src="https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/items/explorer-kit.png" width="28" height="28" alt="탐험세트"> | 강철톤, 마기라스, 한카리아스, 깜까미, 어써러셔, 히드런 | 포켓몬을 5마리 졸업시킬 때마다 보물을 발굴하고 소식 맨 앞에 떠요: 이상한 사탕 1개(85%), 고급 알(12%), 희귀 알(3%), 아주 드물게 전설의 알 |
| **비밀의호박** | <img src="https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/items/old-amber.png" width="28" height="28" alt="비밀의호박"> | 화석 포켓몬¹ 15마리 모두 | 알과 바꾸려고 놓아준 포켓몬이 지금 단계에서 쌓은 경험치의 절반을 새로 태어나는 포켓몬에게 넘겨줘요. 태어나자마자 진화하지는 않아요 |
| **레전드플레이트** | <img src="https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/items/legend-plate.png" width="28" height="28" alt="레전드플레이트"> | 아르세우스 | 가방에 희귀 알과 고급 알 하나씩: 상점처럼 포켓몬을 놓아주고 그 등급 이상의 알을 받아요 |
| **전기구슬** | <img src="https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/items/light-ball.png" width="28" height="28" alt="전기구슬"> | 피카츄의 옷 15개 모두 | 가방에 희귀 알 2개와 이상한 사탕 5개 |
| **타입:널의 알** | <img src="https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/items/mystery-egg.png" width="28" height="28" alt="타입:널의 알"> | 실버디의 메모리 17개 모두⁴ | 지금 포켓몬을 놓아주고 타입:널이 태어나는 알을 받아요 |
| **둥근부적** | <img src="https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/items/oval-charm.png" width="28" height="28" alt="둥근부적"> | 모든 종 (1,025) | 남은 폼이 있는 동안, 아직 모으지 못한 폼이 있는 포켓몬만 그 폼으로 태어나요 |
| **반짝이는부적** | <img src="https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/items/glimmering-charm.png" width="28" height="28" alt="반짝이는부적"> | 모든 폼 (1,350) | 태어나는 포켓몬이 모두 이로치예요 |

포켓몬이 태어날 확률을 바꾸는 건 천공의피리와 둥근부적뿐이고, 둥근부적은 모든 종을 모은 뒤에만 받을 수 있어요. 켄타로스와 네크로즈마의 보상은 이미 다 모은 계열만 낮춰요. 다른 유물은 모두 순수한 보너스라 다른 포켓몬의 확률을 낮추지 않아요.

¹ 암스타, 투구푸스, 프테라, 릴리요, 아말도, 램펄드, 바리톱스, 늑골라, 아케오스, 견고라스, 아마루르가, 파치래곤, 파치르돈, 어래곤, 어치르돈.
² 텅비드, 매시붕, 페로코체, 전수목, 철화구야, 종이신도, 악식킹, 베베놈, 아고용, 차곡차곡, 두파팡.
³ 위대한엄니, 우렁찬꼬리, 사나운버섯, 날개치는머리, 땅을기는날개, 모래털가죽, 무쇠바퀴, 무쇠보따리, 무쇠손, 무쇠머리, 무쇠독나방, 무쇠가시, 고동치는달, 무쇠무인, 굽이치는물결, 무쇠잎새, 꿰뚫는화염, 날뛰는우레, 무쇠암석, 무쇠감투.
⁴ 실버디는 타입:널로 태어나 노말폼으로 진화해요. 도감에 있는 전설·환상의 포켓몬마다(놓아준 개체 포함) 그 폼의 타입 메모리를 줘요(파이어: 불꽃·비행, 가라르 파이어: 악·비행). 벌레타입 전설은 게노세크트뿐이에요. 실버디가 도감에 있으면 메모리마다 그 폼이 해금되고(도감의 폼 목록에 표시), 17개를 모두 모으면 타입:널의 알을 받아요.

**발굴** (돌 탭): 바위 타입 포켓몬을 4종 졸업시킬 때마다(평소 바위 타입 74종, 폼으로 몇 종 더) 화석 알을 하나 발굴해요. 화석 계열마다 하나씩 모두 15개. 화석 알에서는 아직 졸업하지 않은 화석 계열이 무작위로 태어나고, 발굴 전에 졸업한 화석 계열은 발굴해서 연 것으로 15개 중에 쳐요. 화석 알에서 태어난 포켓몬을 졸업 전에 놓아주면 알이 돌아와요. 화석 계열은 졸업하기 전까지 화석 알에서만 태어나고(첫 포켓몬의 계열은 우정 기념 알에서도 돌아와요), 졸업한 뒤에는 다른 포켓몬처럼 모든 알에 들어가 이로치나 다른 성격으로 다시 얻을 수 있어요.

**폼** (업적의 새 탭): 한 종의 모든 폼을 졸업시키면 받아요.

| 업적 | 도구 | 조건 | 보상 |
|---|---|---|---|
| **로토무카탈로그** | <img src="https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/items/rotom-catalog.png" width="28" height="28" alt="로토무카탈로그"> | 로토무의 폼 6개 | 가지고 있으면 그 라인에 없던 폼으로 태어난 포켓몬마다 이상한 사탕 1개 |
| **혜성조각** | <img src="https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/items/comet-shard.png" width="28" height="28" alt="혜성조각"> | 메테노의 코어 7개 | 이상한 사탕 5개 |
| **빨강꿀** | <img src="https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/items/red-nectar.png" width="28" height="28" alt="빨강꿀"> | 춤추새의 스타일 4개 | 이상한 사탕 3개 |
| **보송보송바위** | <img src="https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/items/smooth-rock.png" width="28" height="28" alt="보송보송바위"> | 캐스퐁의 폼 4개 | 이상한 사탕 3개 |
| **바라철록의 사계절** |  | 바라철록의 계절 4개 | 고급 알 1개 |
| **요정의깃털** | <img src="https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/items/fairy-feather.png" width="28" height="28" alt="요정의깃털"> | 플라엣테의 색 5개 | 고급 알 1개 |
| **트리미앙의 열 가지 커트** |  | 트리미앙의 커트 10개 | 희귀 알 1개 |
| **비비용의 스무 가지 무늬** |  | 비비용의 무늬 20개 | 희귀 알 2개 |
| **휘핑팝** | <img src="https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/items/whipped-dream.png" width="28" height="28" alt="휘핑팝"> | 마휘핑의 폼 63개 | 희귀 알 2개와 이상한 사탕 5개 |
| **안농의 알파벳** |  | 안농의 글자 28개 | 희귀 알 2개 |
| **켄타로스의 네 품종** |  | 켄타로스의 품종 4개(관동과 팔데아의 셋) | 보유하면 다 모은 계열이 2분의 1 대신 3분의 1만큼만 태어나요(네크로즈마와 함께면 5분의 1) |
| **네크로즈마의 네 가지 모습** |  | 네크로즈마의 모습 4개 | 보유하면 다 모은 계열이 2분의 1 대신 4분의 1만큼만 태어나요(켄타로스와 함께면 5분의 1) |
| **큐레무의 세 가지 모습** |  | 큐레무의 모습 3개 | 희귀 알 1개와 이상한 사탕 5개 |
| **테오키스의 네 가지 모습** |  | 테오키스의 모습 4개 | 희귀 알 1개와 이상한 사탕 5개 |
| **게노세크트의 다섯 가지 모습** |  | 게노세크트의 카세트 5개 | 희귀 알 1개와 이상한 사탕 5개 |
| **오거폰의 네 가지 모습** |  | 오거폰의 가면 4개 | 희귀 알 1개와 이상한 사탕 5개 |
| **버드렉스의 세 가지 모습** |  | 버드렉스의 모습 3개 | 희귀 알 1개와 이상한 사탕 5개 |
| **지가르데의 세 가지 모습** |  | 지가르데의 모습 3개 | 희귀 알 1개와 이상한 사탕 5개 |
| **테라파고스의 세 가지 모습** |  | 테라파고스의 모습 3개 | 희귀 알 1개와 이상한 사탕 5개 |
| **불비달마의 네 가지 모습** |  | 불비달마의 모습 4개 | 고급 알 1개 |
| **펌킨인의 네 가지 모습** |  | 펌킨인의 크기 4개 | 고급 알 1개 |
| **시비꼬의 네 가지 모습** |  | 시비꼬의 깃털 4개 | 고급 알 1개 |
| **도롱마담의 세 가지 모습** |  | 도롱마담의 도롱이 3개 | 이상한 사탕 3개 |
| **루가루암의 세 가지 모습** |  | 루가루암의 모습 3개 | 이상한 사탕 3개 |
| **윽우지의 세 가지 모습** |  | 윽우지의 모습 3개 | 이상한 사탕 3개 |
| **싸리용의 세 가지 모습** |  | 싸리용의 모습 3개 | 이상한 사탕 3개 |

### 체육관 배지

모든 배지에는 **세대마다 하나의 지방**이 있어요. 그 지방의 해당 타입 포켓몬을 모두 도감에 등록하면 완성되고, **트레이너** 탭의 **업적**에서 받을 수 있어요(배지 카드마다 9개 지방이 받음·받기 가능·진행 중으로 표시돼요). 받은 지방마다 그 타입에 약한 포켓몬이 2.5% 빨리 자라서, 9개 지방을 모두 받으면 22.5%예요. 관동에는 악타입 포켓몬이 없어서 악 배지는 8개 지방(20%)이에요. 여러 배지에 약한 포켓몬은 효과가 누적돼요. 지방이 생기기 전에 받은 배지는 관동 지방(악은 성도)으로 인정돼요. 배지는 아르세우스에게 그 타입의 플레이트도 줘요. 아르세우스는 노말폼으로 태어나고, 도감에 등록되면 지방을 하나라도 받은 배지마다 그 타입의 폼이 해금돼요(진홍배지로 불꽃 아르세우스). 도감의 폼 목록에서 폼마다 필요한 배지를 보여줘요.

| 배지 | 스프라이트 | 타입 | 지방별 포켓몬 | 효과를 받는 포켓몬 |
| :--- | :---: | :---: | :--- | :--- |
| **회색배지** | <img src="https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/badges/1.png" width="28" height="28" alt="회색배지"> | 바위 | 관동 11 · 성도 7 · 호연 12 · 신오 7 · 하나 10 · 칼로스 8 · 알로라 5 · 가라르 6 · 팔데아 8 | 불꽃, 얼음, 비행, 벌레 |
| **블루배지** | <img src="https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/badges/2.png" width="28" height="28" alt="블루배지"> | 물 | 관동 32 · 성도 18 · 호연 28 · 신오 14 · 하나 17 · 칼로스 9 · 알로라 13 · 가라르 11 · 팔데아 12 | 불꽃, 땅, 바위 |
| **오렌지배지** | <img src="https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/badges/3.png" width="28" height="28" alt="오렌지배지"> | 전기 | 관동 9 · 성도 8 · 호연 4 · 신오 7 · 하나 11 · 칼로스 3 · 알로라 6 · 가라르 9 · 팔데아 12 | 물, 비행 |
| **무지개배지** | <img src="https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/badges/4.png" width="28" height="28" alt="무지개배지"> | 풀 | 관동 14 · 성도 10 · 호연 17 · 신오 14 · 하나 20 · 칼로스 9 · 알로라 13 · 가라르 10 · 팔데아 20 | 물, 땅, 바위 |
| **핑크배지** | <img src="https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/badges/5.png" width="28" height="28" alt="핑크배지"> | 독 | 관동 33 · 성도 4 · 호연 5 · 신오 8 · 하나 7 · 칼로스 2 · 알로라 7 · 가라르 5 · 팔데아 12 | 풀, 페어리 |
| **골드배지** | <img src="https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/badges/6.png" width="28" height="28" alt="골드배지"> | 에스퍼 | 관동 14 · 성도 10 · 호연 20 · 신오 9 · 하나 15 · 칼로스 6 · 알로라 8 · 가라르 9 · 팔데아 11 | 격투, 독 |
| **진홍배지** | <img src="https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/badges/7.png" width="28" height="28" alt="진홍배지"> | 불꽃 | 관동 12 · 성도 10 · 호연 6 · 신오 5 · 하나 15 · 칼로스 8 · 알로라 8 · 가라르 7 · 팔데아 10 | 풀, 얼음, 벌레, 강철 |
| **그린배지** | <img src="https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/badges/8.png" width="28" height="28" alt="그린배지"> | 땅 | 관동 14 · 성도 10 · 호연 13 · 신오 10 · 하나 11 · 칼로스 2 · 알로라 4 · 가라르 4 · 팔데아 7 | 불꽃, 전기, 독, 바위, 강철 |
| **윙배지** | <img src="https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/badges/9.png" width="28" height="28" alt="윙배지"> | 비행 | 관동 19 · 성도 19 · 호연 12 · 신오 14 · 하나 18 · 칼로스 8 · 알로라 8 · 가라르 5 · 팔데아 6 | 풀, 격투, 벌레 |
| **인섹트배지** | <img src="https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/badges/10.png" width="28" height="28" alt="인섹트배지"> | 벌레 | 관동 12 · 성도 10 · 호연 14 · 신오 9 · 하나 18 · 칼로스 3 · 알로라 11 · 가라르 8 · 팔데아 7 | 풀, 에스퍼, 악 |
| **레귤러배지** | <img src="https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/badges/11.png" width="28" height="28" alt="레귤러배지"> | 노말 | 관동 22 · 성도 15 · 호연 18 · 신오 17 · 하나 17 · 칼로스 8 · 알로라 12 · 가라르 8 · 팔데아 14 | 노말타입 (노말에 약한 타입이 없어서) |
| **팬텀배지** | <img src="https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/badges/12.png" width="28" height="28" alt="팬텀배지"> | 고스트 | 관동 3 · 성도 1 · 호연 6 · 신오 8 · 하나 9 · 칼로스 8 · 알로라 8 · 가라르 9 · 팔데아 13 | 에스퍼, 고스트 |
| **쇼크배지** | <img src="https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/badges/13.png" width="28" height="28" alt="쇼크배지"> | 격투 | 관동 8 · 성도 3 · 호연 7 · 신오 7 · 하나 15 · 칼로스 4 · 알로라 10 · 가라르 8 · 팔데아 11 | 노말, 얼음, 바위, 악, 강철 |
| **스틸배지** | <img src="https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/badges/14.png" width="28" height="28" alt="스틸배지"> | 강철 | 관동 2 · 성도 4 · 호연 9 · 신오 10 · 하나 12 · 칼로스 4 · 알로라 8 · 가라르 5 · 팔데아 11 | 얼음, 바위, 페어리 |
| **아이스배지** | <img src="https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/badges/15.png" width="28" height="28" alt="아이스배지"> | 얼음 | 관동 5 · 성도 5 · 호연 6 · 신오 6 · 하나 7 · 칼로스 4 · 알로라 1 · 가라르 7 · 팔데아 7 | 풀, 땅, 비행, 드래곤 |
| **라이징배지** | <img src="https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/badges/16.png" width="28" height="28" alt="라이징배지"> | 드래곤 | 관동 3 · 성도 1 · 호연 9 · 신오 6 · 하나 10 · 칼로스 9 · 알로라 7 · 가라르 11 · 팔데아 14 | 드래곤 |
| **악배지** | <img src="https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/badges/59.png" width="28" height="28" alt="악배지"> | 악 | 성도 6 · 호연 10 · 신오 7 · 하나 16 · 칼로스 5 · 알로라 2 · 가라르 10 · 팔데아 13 | 에스퍼, 고스트 |
| **페어리배지** | <img src="https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/badges/48.png" width="28" height="28" alt="페어리배지"> | 페어리 | 관동 5 · 성도 8 · 호연 5 · 신오 2 · 하나 2 · 칼로스 13 · 알로라 12 · 가라르 8 · 팔데아 9 | 격투, 드래곤, 악 |

## 던전

졸업한 포켓몬이 다시 길을 나설 수 있어요. 5개 등급, 13개의 던전마다 저마다의 규칙(한 지방만, 전설 금지, 스타팅만 등)으로 팀을 받고, 다음 등급은 이전 등급의 던전을 모두 이기면 열려요. 도감 페이지에서 포켓몬마다 기술 4개를 고르고 팀을 보내면, 쓰는 토큰이 팀을 한 층씩 내려보내고 그동안 키우는 포켓몬의 성장은 멈춰요. 팀이 긴급 회복의 답을 기다리는 동안만은 다시 자라요(팀이 돌아올 때까지 알, 진화의 돌, 이상한 사탕도 쓸 수 없어요). 전투는 1대1로(쓰러지면 바로 다음 포켓몬이 나오고, 새 상대가 나오면 그 상대에게 더 강한 포켓몬과 교대해요) 게임의 타입, 능력치, 대미지 규칙대로 저절로 진행되고, 일지나 최근 30개를 통째로 간직하는 탐험 기록에서 무대처럼 다시 볼 수 있어요. 무대에서 내 포켓몬은 게임처럼 뒷모습으로 보여요(뒷모습 렌더가 없는 몇몇 폼은 앞모습). 3층마다 주사위가 길을 정해요: 위험한 길은 다음 주사위까지 전투와 함정이 늘어요. T2부터는 층에 다음 층을 건너뛰는 비밀 통로나 상자가 있는 숨겨진 방이 있을 수 있어요. 유물도 효과가 있어요: 모두에게 주는 성장 보너스, 던전 타입에 맞는 보너스, 그 타입이 약한 배지가 층을 싸게 해 줘요(성장처럼 더해져요). 맨 아래에는 보스가 기다려요: 이기면 앱이 가진 가장 좋은 볼을 알아서 던져, 잡으면 그 알을 받아요(마스터볼은 전설의 보스에게만, 팀 화면에서 체크해 두었을 때만). 이미 가진 보스는 대신 던전 등급의 알을 줘요. 전설의 보스는 알을 한 번만 주고(이미 가졌다면 이로치로, 이로치까지 가졌다면 전설의 알로) 그 뒤로는 전리품만 줘요. 그 포켓몬은 200M 토큰이면 졸업하고(보통 전설은 600M), 졸업할 때까지 다른 것으로 바꿀 수 없어요. T2부터는 상자에서도 알이 나와요. 져도 중간에 나와도 지나온 층의 전리품은 지켜요. 아르세우스는 마지막 던전인 시작의 방 끝에서 기다려요. 시작의 방은 T4처럼 전설의 열쇠 1개로 들어가고, 아르세우스는 다른 전설 보스보다 조금 덜 강하며, 던질 때마다 3번에 1번 잡혀요(마스터볼로는 반드시 잡혀요). 한 번 잡기 전에는 어떤 알에서도 태어나지 않아요. 잡은 뒤에는 다른 전설처럼 알에서도 나와 이로치도 노릴 수 있어요. 전리품(나무열매, 기력의조각, 볼, 개체값을 31로 올리는 캡슐, 이상한 사탕, 알)은 가방으로 들어가고, 유물 속 던전 메달은 던전을 처음 이길 때마다 보상을 줘요. 탐험은 한 번에 하나이고, 메뉴 막대에 층과, 손이 필요할 때 "!"가 떠요. **내 팀**에 포켓몬 6마리와 기술을 정해 두면 모든 팀 화면이 거기서 시작하고, 던전마다 페이지에서 야생 포켓몬, 전리품과 그 확률, 지난 탐험을 볼 수 있으며, 타입 상성표도 있어요.

T3 던전을 하나 이기면 **오늘의 던전**(8층, 토큰 200M, 하루 한 번)이, T4를 이기면 **이번 주 던전**(12층, 주 한 번)이 열려요. 보스는 졸업시켰지만 아직 없는 포켓몬의 전투 형태예요: 오늘은 메가진화, 이번 주는 거다이맥스나 원시회귀, 전설의 메가진화. 쓰러뜨리면 그 형태는 영원히 내 것: 도감과 모든 형태 집계에 오르고, 그 종의 졸업한 포켓몬이 팀 화면에서 골라 그 형태로 싸울 수 있어요. 전투 형태 메달은 5, 15, 30, 60, 100개와 전부에서 보상을 줘요.

## 이 밖에도

- **메뉴바 바로가기** — 우클릭·Control 클릭으로 오늘 요약, 새로고침, 도감, 설정, 플로팅 펫 표시·숨김, 종료 메뉴를 엽니다.
- **저전력 모드** — 메뉴바 애니메이션을 배터리 절약 품질로 계속 표시합니다.
- **재연결 시 새로고침** — 네트워크가 복구되면 사용량과 한도를 새로고침합니다.
- **대표 포켓몬** — 도감에서 보유한 종을 골라 현재 키우는 포켓몬과 별개로 메뉴바와 선택적 플로팅 펫에 고정. 고정 중에는 메뉴바가 알·부화·진화를 따라가지 않지만, 육성 과정은 Home에서 계속 확인할 수 있습니다.
- **애니메이션 품질** — 메뉴바 스프라이트와 플로팅 펫이 얼마나 부드럽게 움직일지 고릅니다(배터리 절약 / 기본 / 부드럽게). 상시 표시되는 두 표면이 같은 설정을 씁니다. 기본값 "배터리 절약"은 이 설정이 생기기 전과 같은 프레임 레이트이고, "기본"·"부드럽게"는 배터리를 더 씁니다(실측 유휴 CPU 약 1.8% / 약 5.1%).
- **인터랙티브 플로팅 펫** — 호버로 오늘 사용량, 클릭으로 메인 창, 우클릭 메뉴, 한도 알림은 말풍선으로 표시.
- **서비스별 탭** — Claude Code·Codex·Gemini CLI·Antigravity·OpenCode·Hermes Agent·Cursor·Grok CLI·Copilot CLI·Kiro CLI·Pi Agent·omp·omo·Aside·Kimi Code·Devin CLI 중 2개 이상 감지되면 작은 탭으로 상세를 서비스별 전환(오늘 합계는 통합 유지).
- **공식 한도** — Claude·Codex·Antigravity 5시간/주간 사용률 + 리셋 카운트다운을 오늘 숫자 바로 아래에.
- **추가 스캔 폴더** — 기본 경로 밖에 있는 로그를 위해 프로바이더별로 스캔 루트를 더 지정 (설정 → 고급).
- **여러 Claude 계정** — 설정 폴더(`CLAUDE_CONFIG_DIR`)마다 따로 로그인한 Claude Code 계정은 공식 한도 아래에 각자의 탭이 생기고, 게이지·이상한 사탕·알림·오늘/이번 달 토큰을 따로 보여 줍니다. `~/.claude-*` 폴더와 export 된 `CLAUDE_CONFIG_DIR` 은 자동으로 찾고, 다른 위치는 설정 → 고급에서 추가합니다. 메뉴바 한도 %·컴패니언 기분·예측은 마지막으로 사용한 계정을 따릅니다(설정 → 일반 → 추적할 Claude 계정). 계정마다 claude.ai 세션 키를 따로 넣을 수 있어(설정 → 고급), Keychain 없이도 그 계정의 한도가 계속 갱신됩니다.
- **소진 예측** — 현재 5시간 창이 100%에 도달할 시각 예측.
- **인앱 업데이트** — 원클릭 업데이트 확인, 설정에 현재 버전 표시.
- **통계 페이지**: 홈의 차트 버튼으로 주·월·연을 하나씩 봐요. 합계와 비용, 이전 기간과의 비교, 이 속도의 예상치, 막대마다 그날의 토큰·비용·도구·졸업을 보여 주는 그래프 하나, 토큰이 쓰인 곳(캐시 읽기·쓰기, 입력, 출력, 도구별), 졸업한 포켓몬. 그 아래 설치 이후의 모든 것: 토큰, 포켓몬, 포켓몬당 토큰, 기록(최고의 날·주·달, 연속 사용), 평소의 한 주. 기록과 비용은 올해와 작년분을 로컬에 보관합니다.

- **로컬 저장 백업** — 자동 스냅샷과 손상 복구를 지원하며 설정에서 이전 저장 상태를 복원할 수 있습니다. 백업 기록은 접힌 상태로 시작하며 펼쳐서 확인합니다. **스냅샷 만들기**는 목록 밖에서 바로 사용할 수 있습니다.
- **포켓몬 폼 수집** — 리전폼을 포함해 모든 세대의 다른 폼을 수집하고 폼별 개체를 확인하며, 보유한 폼을 메뉴바·플로팅 펫의 대표로 고릅니다. 모습은 진화와 저장·내보내기에도 이어지고 기존 안농 문자 저장도 읽습니다. [폼 목록](docs/reference/pokemon-forms.md)을 참고하세요.
- **전체 도감**: TokenDex처럼 모든 종을 지방별로 보여 줘요. 완성률과 이로치, 지방마다 진행률과 희귀도, 잡은 종은 희귀도 색으로, 본 종은 흐리게, 없는 종은 번호와 검은 실루엣으로, 모든 스프라이트는 같은 비율로. 전체·보유(페이지별 격자)·미보유로 바꿔 봐요. 전체는 이로치와 진화 라인(아직 없는 종 포함)으로, 미보유는 진화 라인으로 거를 수 있어요.
- **이상한 사탕 일괄 사용** — 여러 사탕을 한 번에 사용하고, 사용 전 성장 결과를 미리 볼 수 있습니다.
- **메뉴바 포켓몬**: 메뉴바 포켓몬을 움직이게, 정지(한 프레임, 다시 그리지 않음), 또는 숨겨서 사용량 글자만 보이게 고릅니다(설정 → 일반). 글자 줄을 모두 끄면 숨긴 포켓몬이 정지 상태로 돌아와 늘 누를 곳이 남습니다.
- **새 폼 배지**: 그 라인에 없던 폼으로 태어난 포켓몬은 자라는 동안 홈에, 졸업 뒤에는 포획 기록에 표시됩니다.
- **피카츄의 옷**: 피카츄가 올 때마다 아직 없는 옷이나 모자를 하나 가져와 자라는 동안 입어요. 도감의 피카츄 페이지에서 다른 피카츄가 입을 옷을 고릅니다. 15개를 모두 모으면 전기구슬을 받아요.
- **생일 선물**: 설정에 생일을 넣으면 그날부터 3개월 안에 앱을 열면 배너가 선물 알을 건네요. 1년에 한 번. 무엇이 태어날지는 비밀이에요.
- **이벤트 알**: 크리스마스, 새해, 밸런타인데이, 포켓몬 데이, 부활절, 핼러윈, 각 계절, 그리고 첫 포획 기념일마다 그날을 위해 그린 알이 와요. 이벤트 동안과 그 뒤 2주 동안 배너가 알을 건네요. 1년에 한 번. 계절 알은 그 계절 중 언제든 받을 수 있고, 계절마다 한 번이에요. 그 이벤트의 포켓몬이 태어나고, 이로치일 때가 많아요.
- **새 소식**: 신문 버튼에서 모든 변경을 업데이트별로 새 기능, 개선, 수정으로 나눠 볼 수 있고, 업데이트 뒤에는 지난번 이후 바뀐 점을 배너가 알려 줘요.
- **아이디어**: 전구 버튼으로 아이디어나 버그를 이 저장소의 이슈로 보내요. GitHub CLI(`gh`)로 로그인돼 있으면 앱이 직접 올리고, 아니면 브라우저에 미리 채워 열어요. 앱은 토큰을 갖고 있지 않아요.
- **한도 사용 페이스** — 게이지의 경과 시간 표식과 6단계 색상으로 사용 속도를 확인합니다. 메뉴바 한도 비율도 같은 색상을 사용합니다.

<img src="assets/screenshot-usage-recap-ko.png" width="360" alt="선택한 기간의 사용량 돌아보기">

<small>위 홈·설정·폼·상점·가방·난이도·일별 차트·회고 이미지는 샘플 데이터로 실제 UI를 로컬 렌더링한 이미지입니다.</small>

## 지원 도구

| 도구 | 집계 범위 | 공식 한도 |
|---|---|---|
| **Claude Code** | 오늘 · 5시간 블록 · 주 · 월 | ✅ 5시간 / 주간 |
| **Codex** | 오늘 · 주 · 월 | ✅ 5시간 / 주간 |
| **Gemini CLI** | 오늘 · 주 · 월 | — |
| **Antigravity** | 오늘 · 5시간 블록 · 주 · 월 | ✅ 5시간 / 주간 |
| **OpenCode** | 오늘 · 5시간 블록 · 주 · 월 | ✅ 5시간 / 주간 / 월간 (OpenCode Go) |
| **Hermes Agent** | 오늘 · 5시간 블록 · 주 · 월 | — |
| **Cursor** | 오늘 · 5시간 블록 · 주 · 월 | — |
| **Grok Build CLI** | 오늘 · 5시간 블록 · 주 · 월 | ✅ 크레딧 한도 (주간) |
| **Copilot CLI** | 오늘 · 5시간 블록 · 주 · 월 | — |
| **Kiro CLI** | 오늘 · 5시간 블록 · 주 · 월 | — (추정치) |
| **Pi Agent** | 오늘 · 5시간 블록 · 주 · 월 | — |
| **omp** (oh-my-pi) | 오늘 · 5시간 블록 · 주 · 월 | — |
| **omo** (senpi) | 오늘 · 5시간 블록 · 주 · 월 | — |
| **Aside** | 오늘 · 5시간 블록 · 주 · 월 | — |
| **Kimi Code** | 오늘 · 5시간 블록 · 주 · 월 | — |
| **Devin CLI** | 오늘 · 5시간 블록 · 주 · 월 | — |

Grok 지원은 Grok Build CLI의 로컬 세션 로그를 읽습니다. Grok Bot의 클라우드 사용량과 구독 한도는 연동되어 있지 않습니다.

모두 로컬에서 읽습니다 — 외부 사용량 CLI 불필요. 도구는 프로바이더 구현과 등록으로 추가합니다([CONTRIBUTING.ko.md](CONTRIBUTING.ko.md) 참고).

## 설치

### 요구사항

macOS 14+ (Apple Silicon 또는 Intel). 끝입니다 — 토큰 사용량은 로컬 Claude Code·Codex·Gemini CLI·Antigravity·OpenCode·Hermes Agent·Cursor·Grok CLI·Copilot CLI·Kiro CLI·Pi Agent·omp·omo·Aside·Kimi Code·Devin CLI 데이터에서 직접 읽으며 외부 사용량 CLI가 필요 없습니다.

### Homebrew

```bash
brew install --cask chattymin/tap/poke-token-bar
```

ad-hoc/자체 서명 앱이라 Cask 설치 시 격리 속성을 자동 제거합니다.

### 직접 설치 (Homebrew 없이)

Homebrew를 쓰지 않는다면 [최신 릴리스](https://github.com/chattymin/PokeTokenBar/releases/latest)에서 `PokeTokenBar.zip`을 내려받아 압축을 풀고 `PokeTokenBar.app`을 `/Applications`로 드래그합니다.

이 앱은 ad-hoc/자체 서명(Apple 개발자 계정 공증 없음)이라 첫 실행 시 Gatekeeper가 "확인되지 않은 개발자" 경고를 띄웁니다. 아래 둘 중 하나로 한 번만 해제하면 됩니다.

- **Finder:** `PokeTokenBar.app`을 우클릭(또는 Control+클릭) → **열기** → 대화상자에서 **열기**를 다시 클릭.
- **터미널:** `xattr -dr com.apple.quarantine /Applications/PokeTokenBar.app`

(Homebrew Cask는 격리 속성을 자동 제거하므로 이 과정이 필요 없습니다.)

### 소스 빌드

```bash
swift build                  # 디버그
swift test                   # 단위 테스트
./scripts/build-app.sh       # release → PokeTokenBar.app → /Applications
```

## 데이터 소스

| 소스 | 용도 | 비고 |
|---|---|---|
| `~/.claude/projects/**/*.jsonl`, `<설정 폴더>/projects/**/*.jsonl` | Claude Code daily/blocks/weekly/monthly | 직접 읽음; 메시지 id 로 중복제거; 증분 캐시 |
| `~/.claude.json`, `~/.claude-*/.claude.json` | Claude 계정: 로그인된 설정 폴더와 계정 이름 | `oauthAccount` 블록만 사용; export 된 `CLAUDE_CONFIG_DIR` 과 설정 → 고급의 폴더도 포함 |
| `~/.claude/history.jsonl`, `<설정 폴더>/history.jsonl` | 계정별 Claude 토큰; 마지막으로 사용한 계정 | 세션 id 와 프롬프트 시각만 읽고 프롬프트 내용은 읽지 않음; 새로 추가된 줄만 읽음 |
| `~/.gemini/tmp/**/chats/*.json(l)` | Gemini CLI daily/monthly | 세션 레코드(메시지별 `tokens`); 주간 = daily 합산 |
| `~/.gemini/antigravity/conversations/*.db`<br>`~/.gemini/antigravity-cli/conversations/*.db`<br>`~/.gemini/antigravity-ide/conversations/*.db` | Antigravity daily/blocks/weekly/monthly | SQLite 읽기 전용; Cascade protobuf blob 의 호출별 사용량; Antigravity 2.0/Core, CLI, IDE 모두 지원; Gemini 에 합산하지 않는 별도 프로바이더; 구독제라 비용은 추정하지 않음 |
| `~/.codex/sessions/**/*.jsonl` | Codex daily/monthly | `token_count` 이벤트; 주간 = daily 합산 |
| `~/.local/share/opencode/opencode.db` | OpenCode daily/blocks/weekly/monthly | SQLite 읽기 전용; 레거시 `storage/message` JSON도 지원 |
| `~/.hermes/state.db` | Hermes Agent daily/blocks/weekly/monthly | SQLite 읽기 전용; 세션 토큰 합계와 저장된 비용 |
| `~/Library/Application Support/Cursor/User/globalStorage/state.vscdb` | Cursor daily/blocks/weekly/monthly | SQLite 읽기 전용 폴백(`cursorDiskKV` 버블 엔트리의 `tokenCount`); 로그인 상태면 `cursor.com` 대시보드 API 가 기본 소스(개인정보 항목 참고) |
| `cursor.com`(대시보드 API) | Cursor daily/blocks/weekly/monthly | 비공식 JSON endpoint(`get-filtered-usage-events`); 세션은 `state.vscdb` 의 `cursorAuth/accessToken` 또는 `CURSOR_SESSION_TOKEN`; 프로바이더가 새로고침될 때마다 다시 가져옴; 네트워크 실패 시 계정별로 분리된 최대 6시간 이내의 디스크 캐시로 대체; `CURSOR_USAGE_API=0` 으로 비활성화 |
| `opencode.ai`(OpenCode Go 사용량 API) | OpenCode Go 공식 5시간 / 주간 / 월간 사용률 | opencode.ai 콘솔이 쓰는 비공식 JSON 엔드포인트(`/zen/go/v1/usage`); `opencode.db` 의 `credential` 테이블에 저장된 OpenCode Go API 키(없으면 `auth.json`)를 Bearer 로 사용; Go 키가 있을 때만 호출하고, 실패하면 한도만 숨김 |
| `cli-chat-proxy.grok.com`(Grok 결제 API) | Grok 공식 크레딧 한도(현재 기간) | Grok CLI `/usage` 화면이 쓰는 비공식 JSON 엔드포인트(`/v1/billing?format=credits`); `$GROK_HOME/auth.json`(기본 `~/.grok`)의 액세스 토큰을 Bearer 로 사용; 토큰을 직접 갱신하지 않아 로그인이 만료되면 Grok 을 한 번 실행하라고 안내; 실패하면 한도만 숨김 |
| `api2.cursor.sh`(대시보드 한도 API) | Cursor 공식 월간 included usage | Connect RPC `GetCurrentPeriodUsage`; `state.vscdb` 또는 `CURSOR_SESSION_TOKEN` 의 Bearer JWT; usage events 와 같은 비활성화 스위치 |
| `~/.grok/sessions/**/updates.jsonl` | Grok Build CLI daily/blocks/weekly/monthly | `turn_completed` 레코드(턴 단위 `usage`, 서버 보고 비용); `$GROK_HOME` 설정 시 그 경로; 서브에이전트 세션은 토큰이 부모 턴에 이미 포함돼 제외 |
| `~/.copilot/session-store.db` | Copilot CLI daily/blocks/weekly/monthly | SQLite 읽기 전용; `assistant_usage_events` 1행 = API 호출 1건; `$COPILOT_HOME` 설정 시 그 경로; `input_tokens` 에 캐시 프롬프트가 이미 포함돼 캐시 read/write 를 빼고 집계; premium request 과금이라 비용은 추정하지 않음 |
| `~/Library/Application Support/kiro-cli/data.sqlite3`<br>`~/.kiro/sessions/cli/*.jsonl`<br>`~/.kiro/sessions/<ws>/<session>/messages.jsonl` | Kiro CLI daily/blocks/weekly/monthly | 2.20 이전 SQLite + 2.20+/`--v3` JSONL; 어느 쪽도 실제 토큰 수를 저장하지 않아 input 은 매 턴 재전송되는 누적 대화 텍스트를 바이트÷4 로 **추정**; `usage_summary` 크레딧은 USD 로 바꾸지 않음; `/clear`·압축으로 지워진 SQLite 대화의 이미 집계된 토큰은 앱을 재시작하기 전까지 계속 집계; `$KIRO_CLI_HOME`·`$KIRO_HOME` 지원 |
| `~/.pi/agent/sessions/**/*.jsonl` | Pi Agent daily/blocks/weekly/monthly | 모든 프로젝트의 저장된 usage를 직접 집계; `$PI_CODING_AGENT_DIR`·`$PI_CODING_AGENT_SESSION_DIR` override 지원; output에는 reasoning이 이미 포함되어 별도 합산하지 않음; fork 복사본은 entry ID로 중복 제거; 기록된 비용 사용 |
| `~/.omp/agent/sessions/**/*.jsonl` | omp (oh-my-pi) daily/blocks/weekly/monthly | pi 포맷 세션 JSONL; 모든 assistant `usage` 이벤트를 합산(되돌린 분기도 이미 청구된 토큰)하고 서브에이전트 세션 파일도 부모에 합산되지 않으므로 함께 집계; `$OMP_CODING_AGENT_DIR` 지원; 이벤트별 `cost` 가 기록돼 있으면 그대로 신뢰; `bridge/` 아래 변환 사본은 원본이 이미 집계되므로 제외 |
| `~/.omo/agent/sessions/**/*.jsonl`<br>`~/.senpi/agent/sessions/**/*.jsonl` | omo (senpi) daily/blocks/weekly/monthly | senpi `docs/session-format.md` 의 pi 포맷 JSONL; assistant usage, 중첩 `toolResult.usage`, compaction/branch-summary usage 를 합산; output 에 reasoning 이 이미 포함; `cacheWrite1h` 는 cache write 에 더함; `$OMO_CODING_AGENT_DIR`·`$SENPI_CODING_AGENT_DIR` 지원; 기록된 `usage.cost` 는 가격 추정치이지 구독 청구액이 아님 |
| `~/.aside/u/*/state.db` | Aside daily/blocks/weekly/monthly | SQLite 턴 합계 읽기 전용; 삭제된 턴은 스캔 캐시 초기화까지 집계 유지; 기록된 비용만 사용 |
| `~/.kimi-code/sessions/**/agents/*/wire.jsonl` | Kimi Code daily/blocks/weekly/monthly | 모든 `usage.record`(요청 단위, `turn`·`session` 스코프)를 메인·서브에이전트 wire 파일 전체에서 합산; `$KIMI_CODE_HOME` 과 Kimi 데스크톱 런타임 루트 지원; `/fork` 사본은 레코드 내용으로 중복 제거; Kimi 는 비용을 기록하지 않아 비용은 '없음'으로 표시 |
| `~/.local/share/devin/cli/sessions.db` | Devin CLI daily/blocks/weekly/monthly | SQLite 읽기 전용; `message_nodes`의 metrics와 세션 모델을 연결; input과 캐시 토큰은 별도 집계; 같은 세션의 분기 사본은 message ID로 중복 제거; `$XDG_DATA_HOME`과 추가 스캔 폴더 지원; 비용은 추정하지 않음 |
| Keychain(`Claude Code-credentials`, 다른 설정 폴더마다 `Claude Code-credentials-<hash>`) / `<설정 폴더>/.credentials.json` → `api.anthropic.com` | 계정별 Claude 공식 5h/주간 % | 비공식 endpoint; Keychain 은 **갱신 버튼을 누를 때만** 읽음 — 자동 폴링은 읽지 않음 |
| `codex app-server` | Codex 공식 5h/주간 % | 로컬 자식 프로세스; 계정 snapshot만, 모델 turn 없음 |
| [PokéAPI](https://pokeapi.co/) — `pokeapi.co`, `graphql.pokeapi.co` | 포켓몬 종·능력치·특성·기술·진화 | 런타임 fetch; 로컬 캐시, 번들 안 함 |
| `raw.githubusercontent.com/PokeAPI/sprites` | 포켓몬·아이템 스프라이트 | 런타임 fetch; Application Support 에 캐시, 번들 안 함 |
| `status.claude.com`, `status.openai.com` | 프로바이더 장애 배너 | statuspage 요약; 표시 전용 — 설정에서 끌 수 있음 |
| `api.github.com` | 업데이트 확인 | 최신 릴리스 태그; 기동 시와 팝오버를 열 때 |

로그가 **위 기본 경로 밖**에 있으면 **설정 → 고급 → 추가 스캔 폴더**에 그 폴더를 넣습니다. 프로바이더를 먼저 고르세요 — 폴더는 그 프로바이더만 파싱하므로, Gemini 칸에 Claude 로그를 넣으면 토큰이 잘못 귀속됩니다. 추가 폴더는 기본 위치에 *더해질* 뿐 대체하지 않습니다.

## 프라이버시 & 권한

- **온디바이스 우선.** 토큰 사용량은 로컬 Claude Code·Codex·Gemini CLI·Antigravity·OpenCode·Hermes Agent·Cursor·Grok CLI·Copilot CLI·Kiro CLI·Pi Agent·omp·omo·Aside·Kimi Code·Devin CLI 데이터에서 직접 읽습니다. 사용량을 업로드하거나 모델 turn을 실행하지 않습니다. Claude 사용량을 계정별로 나누려고 설정 폴더마다 `history.jsonl` 에서 세션 id 와 프롬프트 시각만 읽습니다. 프롬프트 내용은 읽지 않고 Mac 밖으로 보내지도 않습니다.
- **외부 요청.** 앱은 완전 오프라인이 아닙니다. 15개 호스트에 접속합니다 — `pokeapi.co`·`graphql.pokeapi.co`(종·진화), `raw.githubusercontent.com`(스프라이트), `api.anthropic.com`(Claude 공식 한도), `claude.ai`(설정에서 claude.ai 세션 키를 저장한 경우의 Claude 공식 한도 — 그 키만, 프롬프트·프로젝트 경로 없음), `cursor.com`(로컬에서 Cursor 에 로그인한 경우 Cursor 사용량 요약 — 세션 자격증명만, 프롬프트·프로젝트 경로 없음), `api2.cursor.sh`(Cursor 공식 월간 included usage — Bearer JWT만, IDE 로그인과 동일한 자격증명), `opencode.ai`(로컬에 OpenCode Go 키가 연결된 경우의 OpenCode Go 공식 한도 — API 키만), `cli-chat-proxy.grok.com`(Grok CLI 에 로그인한 경우의 Grok 공식 크레딧 한도 — 액세스 토큰만), `cloudcode-pa.googleapis.com`·`daily-cloudcode-pa.googleapis.com`(Antigravity 공식 한도)와 `oauth2.googleapis.com`(토큰 갱신), `status.claude.com`·`status.openai.com`(장애 배너 — 설정에서 끌 수 있음), `api.github.com`(업데이트 확인). **어느 요청에도 사용량 로그·프롬프트·프로젝트 경로는 담기지 않습니다** — 요청 자체만 나갑니다(Cursor 는 웹 대시보드와 동일하게 본인 사용량 행을 가져오기 위해 세션 쿠키를 보냅니다).
- **Keychain(선택).** Claude OAuth 자격증명은 **갱신 버튼을 누를 때만** 읽습니다(설정, 또는 팝오버의 한도 행). 자동 폴링은 Keychain 을 건드리지 않으므로 비밀번호 프롬프트가 뜨지 않고, `~/.claude/.credentials.json` 이 있으면 매 폴마다 다시 읽어 `/login` 으로 계정을 바꿔도 갱신 버튼 없이 따라갑니다. 토큰은 메모리에만 두며 **앱 자체 Keychain 항목은 만들지 않습니다.** 자격증명 파일이 없으면 캐시 토큰이 만료될 때까지(또는 갱신 버튼을 누를 때까지) 한도는 이전 값으로 남습니다. 설정에서 끄면 한도 섹션만 숨겨집니다. Claude 계정이 여러 개면 갱신할 때 다른 설정 폴더의 항목도 폴더마다 한 번씩 읽고, 프롬프트를 거절하면 나머지는 묻지 않습니다.
- **포켓몬 데이터와 에셋**은 런타임에 PokéAPI에서 받아오며 `~/Library/Application Support/PokeTokenBar/`에만 캐시됩니다. 생성된 개체값(IV·성별·특성·배운 기술 등)은 값이 변하지 않도록 로컬 파트너 세이브에 저장됩니다. 앱 바이너리와 릴리스 아티팩트에는 포켓몬 에셋이 포함되지 않습니다.

## 기여자

크기에 상관없이 모든 기여를 환영합니다 — 빌드·테스트·풀 리퀘스트 방법은 [CONTRIBUTING.ko.md](CONTRIBUTING.ko.md)를 참고하세요.

[![Contributors](https://contrib.rocks/image?repo=chattymin/PokeTokenBar)](https://github.com/chattymin/PokeTokenBar/graphs/contributors)

## 라이선스 & 면책

**MIT** — [LICENSE](LICENSE) 참고. MIT는 본 프로젝트의 **원본 소스 코드에만** 적용되며, 앱을 통해 접근하는 제3자의 상표·아트워크·데이터에 대한 권리는 부여하지 않습니다.

PokeTokenBar는 **비공식·비상업 팬 프로젝트**입니다. **Nintendo, Game Freak, Creatures Inc., The Pokémon Company와 제휴·보증·후원·승인 관계가 없습니다.** "포켓몬(Pokémon)"과 관련 명칭·캐릭터·이미지는 각 권리자의 상표 및 저작물이며, 본 프로젝트는 어떤 포켓몬 지식재산에 대해서도 소유권이나 권리를 주장하지 않습니다.

- **앱 바이너리와 릴리스 아티팩트에는 포켓몬 에셋이 포함되지 않습니다.** 포켓몬 종 데이터와 스프라이트는 공개 [PokéAPI](https://pokeapi.co)에서 **런타임에** 받아 사용자 기기에 로컬 캐시되며, PokéAPI를 통해 제공되는 스프라이트 이미지의 권리는 각 권리자에게 있습니다.
- 저장소 문서(스크린샷/GIF)에 보이는 포켓몬 이미지는 앱 기능 설명 목적으로만 표시됩니다.
- 본 앱은 **개인적·비상업적 용도로만** 무료 제공됩니다.
- 권리자께서 본 프로젝트에 대해 우려가 있으시면 이슈를 열거나 메인테이너에게 연락 주시면 신속히 대응하겠습니다.

*본 프로젝트는 어떠한 보증도 없이 "있는 그대로" 제공됩니다. 본 고지는 법률 자문이 아닙니다.*
