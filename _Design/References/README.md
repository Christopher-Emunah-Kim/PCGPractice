# PROJECT — PCGPractice
> 프로젝트 정보 허브.

## 프로젝트 개요
```yaml
name:    PCGPractice
purpose: UE5 기술 학습·실험
genre:   PCG + 게임플레이 패턴 Variant 실험
tech:    UE5 C++
mode:    싱글플레이어 (네트워크 없음)
arch:    Variant 구조 — 독립적 게임플레이 시스템 단위
```

## 폴더 구조
```
_Design/
  References/
    README.md          ← 이 파일
    ARCH_SNAPSHOT.md   ← 구현 스냅샷 (INIT 자동 로드)
  Plans/
    active/            ← 진행 중 계획서 (PLAN_*.md)
    completed/         ← 완료된 계획서
  Changesets/
    CHANGESET.md       ← 코드 변화 추적
  Handoff/
    HANDOFF_LATEST.md  ← 세션 간 컨텍스트 이어받기
  Learning/
    reports/           ← 세션별 학습 노트
  Reviews/             ← 시니어 리뷰 결과
  SessionState/
    active.md          ← 세션 체크포인트
  TODO.md              ← 작업 현황

.claude/
  refs/                ← 시스템 운영 규칙 (protocols, constraints 등)
  skills/              ← Skill 파일들
  agents/              ← Agent 파일들
  rules/               ← 코딩 컨벤션 (general-code.md)
```

## Variant 목록
| 폴더 | 내용 |
|------|------|
| Variant_Combat | 3인칭 전투 — 콤보/차지공격, AI, HP/사망/리스폰 |
| Variant_SideScrolling | 횡스크롤 — 벽점프, 코요테타임, 소프트플랫폼, NPC |
| Variant_Platforming | 플랫포머 — 대시, 멀티점프, 벽점프 |
