# catspuzzle

고양이 테마 2D 캐주얼 퍼즐 게임. iOS + Android 동시 출시 목표.

## 스택
- **Flutter + Flame** (단일 코드베이스, 메타 UI는 Flutter 위젯, 게임 보드는 Flame)
- 레벨 데이터: JSON (에디터 없음 → 필요 시 자체 레벨 툴 제작)
- 연출은 스프라이트 시트 위주. 저사양 안드로이드를 고려해 파티클/셰이더는 최소화

## 협업 (Claude Code ↔ gjc)
Claude Code는 orca 안에서 동작하고, gjc(`gjc`, v0.17.x, Opus 5)는 교차 검토와 기획을 맡는다.
- 기획/요구사항 정리: `gjc deep-interview` (모호한 부분을 질문으로 좁힘)
- 설계 합의: `gjc ralplan` (planner/architect/critic 합의)
- 단발 교차 검토: `gjc -p --no-session --thinking low "<짧은 질문>"`, 답변 길이 제한을 명시할 것
- 큰 기획 결정(장르 메커닉, 수익화, 아키텍처)은 gjc 의견을 한 번 받아 대조한 뒤 확정

## 토큰 절약
- headroom 설치됨 (`headroom`, pip). 새 세션은 `headroom wrap claude`로 띄우면 도구 출력이 압축된다.
- 긴 로그/빌드 출력은 `| tail`, `| grep`으로 잘라서 읽기. gjc에 넘기는 프롬프트도 요약본만.

## 디자인
- UI 작업 시 ui-ux-pro-max(Flutter 스택 지정)와 hallmark(AI 티 나는 패턴 회피: 보라색 그라데이션, 모든 요소 중앙 정렬 등)를 적용
- 디자인 토큰(색/타이포/간격)은 `lib/theme/`에 한 곳으로 모은다
