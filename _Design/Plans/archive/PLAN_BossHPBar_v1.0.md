# PLAN_BossHPBar_v1.0
```yaml
date:    2026-04-09
sprint:  SPRINT-6
status:  ACTIVE
designs: [AI_에너미 시스템 기획 v1.1.md, UI관리 시스템 기획 v1.1.md]
```

## GOAL
> 보스 스폰 시 화면 상단 중앙에 보스 전용 HP 바를 표시하고 보스 사망 시 숨기는 파이프라인 구현 (URSBaseWidget + UIManagerSubsystem PERSISTENT 레이어 경유).

## SCOPE
```yaml
new_files:
  - Source/RoastStaffGAS/Public/UI/Enemy/BossHPBarWidget.h
  - Source/RoastStaffGAS/Private/UI/Enemy/BossHPBarWidget.cpp
modified_files:
  - Source/RoastStaffGAS/Public/Data/EnumUITypes.h       # EUIID::BOSS_HP_BAR 추가
  - Source/RoastStaffGAS/Public/Character/Enemy/BossEnemy.h  # GetPhase2HPRatio() getter 추가
  - Source/RoastStaffGAS/Private/System/EnemySpawner.cpp # TODO → 실제 로직 교체
new_datatables: []
new_tags:       []
editor_only:
  - WBP_BossHPBar (UMG 에셋, Content/UI/Enemy/)
  - UIManagerSettings: UIClassMap + UILayerMap에 BOSS_HP_BAR 매핑
```

## FLOW
```
[스폰 시]
EnemySpawner::InitializeEnemyByType() — case EAIType::BOSS
    │
    ├─ ABossEnemy::InitializeBossParams() 호출
    │
    ├─ UMS->OpenUIByID(EUIID::BOSS_HP_BAR)
    │       ├─ 성공 → Cast<UBossHPBarWidget>
    │       │         ├─ Cast 성공 → Widget->BindToASC(Boss->GetASC(), Boss->GetPhase2HPRatio())
    │       │         └─ Cast 실패 → ensureMsgf + 전투 계속 (HUD 없이 진행)
    │       └─ 실패(UIClassMap 미등록) → UMS 내부 경고 로그
    │
    └─ Boss->OnBossKilledDel.AddUniqueDynamic(OnBossKilled)

[런타임 — HP 변화]
ABossEnemy::ASC 어트리뷰트 변화
    └─ UBossHPBarWidget::OnHealthChanged(NewHP, MaxHP)
            ├─ ProgressBar 비율 갱신
            ├─ HP/MaxHP ≤ Phase2Ratio 최초 진입 → Phase2 색상 전환 (bPhase2Triggered 플래그)
            └─ HP ≤ 0 → PlayAnimation(FadeOutAnimation) → OnAnimationFinished → OnCloseRequested

[사망 시]
ABossEnemy::HandleDeath() → OnBossKilledDel.Broadcast()
    └─ EnemySpawner::OnBossKilled()
            └─ bIsClosing 확인
                    ├─ false → bIsClosing=true, UMS->CloseUIByID(EUIID::BOSS_HP_BAR)
                    └─ true  → no-op (FadeOut 이미 진행 중)

[FadeOut 완료 시]
UBossHPBarWidget::OnAnimationFinished
    └─ bIsClosing=true, OnCloseRequested() → UMS CloseUIInternal
```

## EDGE_CASES
```
| 상황                                          | 처리                                             | 기획서 근거 |
|-----------------------------------------------|--------------------------------------------------|-------------|
| UIClassMap에 BOSS_HP_BAR 미등록               | UMS 내부 경고 로그, 전투 계속                    | -           |
| Cast<UBossHPBarWidget> 실패                   | ensureMsgf + 전투 계속 (HUD 없이)                | -           |
| FadeOut 중 OnBossKilled 도착 (이중 Close)     | bIsClosing 플래그로 중복 CloseUI 무시            | -           |
| Phase2 임계값 0 이하로 설정된 경우             | Phase2 색상 전환 즉시 발생 (DataTable 검증 필요) | -           |
| 보스 재스폰 (풀 재사용)                        | BindToASC 재호출 + bIsClosing/bPhase2Triggered 리셋 | 풀링 정책  |
```

## REVIEW_NOTES
```
기획서 일관성: ✓
  - AI v1.1 § 보스 UI: "보스 스폰 시 HUD 상단 중앙 체력바 표시" 충족
  - UI v1.1 § 레이어: PERSISTENT = 입력 모드 변화 없음 → 전투 중 GameOnly 유지 정합

누락 예외처리:
  - Phase2 색상값 미확정 (아트 확정 후 WBP에서 조정)
  - FadeOut 지속시간 미확정 (임시값 1.0f, 아트 확정 후 조정)
  - WBP 레이아웃 수치 미확정 (상단 중앙 앵커 배치 기준)

기획서 정정:
  - UI v1.1 위젯 목록: BOSS_HP_BAR 미등재 → 추가 권장
```

---
## REVIEW_STATUS
```
| 단계          | 상태 | 날짜       | 주요 지적 |
|---------------|------|------------|-----------|
| Cross-Review  | -    | -          | -         |
| Senior-Review | -    | -          | -         |
| Learn-Report  | -    | -          | -         |

verdict:    PENDING
unresolved: []
```
