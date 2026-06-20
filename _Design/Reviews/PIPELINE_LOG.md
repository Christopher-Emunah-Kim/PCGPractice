# PIPELINE_LOG — 파이프라인 자가 진단 기록
> SESSION_END [PR] 단계에서 자동 기록.
> 패턴이 3회 이상 반복되면 구조적 문제로 판단 → 즉시 개선 제안.

---

## 로그

## 2026-04-07
관찰: EXPLAIN_IMPL 능동 진단 포함 여부 1회 왕복. 초기 제안 명세 불충분.
개선: 없음 (건너뛰기)

## 2026-04-10
관찰: PIPELINE_FLOW 섹션 인라인→외부파일 이동 시 EXPLAIN_IMPL 줄 소실 (시니가 직접 발견). CONSTRAINTS 위치 논쟁 2회 왕복.
개선: CLAUDE.md PIPELINE 섹션 EXPLAIN_IMPL 줄에 [고정] 마커 추가 — 편집 시 삭제 방지

## 2026-04-13
관찰: ① IA_Attack 제거→복구 2회 왕복 (M-3 계획에 M-5 의존성 미명시). ② 계획서 GE명(GE_WeaponDamage/GE_EnemyDamage)이 실제 에셋(GE_Damage)과 달라 구현 후 사용자가 발견.
개선: coding SKILL.md [C] 섹션에 [에셋 선참조 체크] 규칙 추가 — GE/Widget/DT 에셋명 Glob 확인 후 코드 작성
