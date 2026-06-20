# PLAN_BossHPBarRefactor_v1.0
```yaml
date:    2026-04-25
sprint:  SPRINT-8
status:  ACTIVE
designs: []
```

## GOAL
> BossHPBarWidget을 UMS PERSISTENT 레이어 독립 위젯에서 RSHUDWidget의 자식으로 편입해 UMS 의존성을 제거하고 HUD 응집도를 높인다.

## SCOPE
```yaml
new_files:      []
modified_files:
  - Source/RoastStaffGAS/Public/UI/Enemy/BossHPBarWidget.h
  - Source/RoastStaffGAS/Private/UI/Enemy/BossHPBarWidget.cpp
  - Source/RoastStaffGAS/Public/UI/RSHUDWidget.h
  - Source/RoastStaffGAS/Private/UI/RSHUDWidget.cpp
  - Source/RoastStaffGAS/Public/System/EnemySpawner.h
  - Source/RoastStaffGAS/Private/System/EnemySpawner.cpp
  - Content/UI/Ingame/WBP_HUD.uasset  (에디터)
new_datatables: []
new_tags:       []
```

## INTEGRATION_POINTS
```yaml
owner:       URSHUDWidget
entry:       URSHUDWidget::ShowBossHPBar / HideBossHPBar  (AEnemySpawner에서 호출)
depends_on:  ARSPlayerController  (HUDWidget getter 경유)
ref_pattern: WBP_CharacterStatPopup Visibility 토글 패턴
             (NativeOnInitialized Collapsed 초기화 → 메서드에서 토글)
arch_impact:
  CLASS_REGISTRY:
    - URSHUDWidget 책임 추가: BossHPBar 소유·표시 제어
    - UBossHPBarWidget 비책임 추가: UIManagerSubsystem 의존 없음
  INTEGRATION_MAP:
    - 추가: EnemySpawner::InitializeEnemyByType → RSHUDWidget::ShowBossHPBar (보스 스폰 시)
    - 추가: EnemySpawner::OnBossKilled → RSHUDWidget::HideBossHPBar (보스 사망 폴백)
    - 제거: EnemySpawner → UMS::OpenUIByID(BOSS_HP_BAR)
    - 제거: BossHPBarWidget::OnFadeOutFinished → UMS::CloseUIByID(BOSS_HP_BAR)
  DESIGN_DECISIONS:
    - BossHPBar PERSISTENT → HUD 자식 전환: UMS 레이어 단순화 + HUD 위젯 응집도 향상
```

## FLOW
```
[보스 스폰] EnemySpawner::InitializeEnemyByType (AIType == BOSS)
    │
    ▼
ARSPlayerController 획득 → Cast<URSHUDWidget> GetHUDWidget()
    │
    ├─ HUD 유효 ──→ HUD->ShowBossHPBar(BossASC, Phase2Ratio)
    │                   └─ WBP_BossHPBar->SetVisibility(Visible)
    │                   └─ WBP_BossHPBar->BindToASC(ASC, Phase2Ratio)
    └─ HUD null ──→ KHS_WARN + return

[보스 사망 — HP=0]
BossHPBarWidget::OnCurrentHPChanged → TriggerFadeOut
    ├─ Anim_FadeOut 있음 ──→ PlayAnimation → OnFadeOutFinished
    │                             └─ SetVisibility(Collapsed)
    └─ Anim_FadeOut 없음 ──→ EnemySpawner::OnBossKilled
                                  └─ CachedHUDWidget->HideBossHPBar()
                                       └─ WBP_BossHPBar->SetVisibility(Collapsed)
```

## SCHEMA
```
해당 없음 (DataTable 변경 없음)
```

## EDGE_CASES
```
| 상황 | 처리 | 근거 |
|------|------|------|
| FadeOut 애니메이션 진행 중 OnBossKilled 폴백 도달 | bIsClosing 체크로 중복 Collapsed 방지 | 기존 로직 유지 |
| WBP_BossHPBar BindWidget 누락 (에디터 미작업) | ensureMsgf로 조기 감지 | MODULE-2 NativeConstruct |
| PC 또는 HUDWidget null (레벨 전환 타이밍) | null 체크 + KHS_WARN | MODULE-3 |
| 보스 재스폰 (같은 레벨에서 보스 웨이브 2회) | BindToASC 재호출 시 기존 구독 해제 후 재구독 — 기존 로직 유지 | BossHPBarWidget::BindToASC |
```

## REVIEW_NOTES
```
기획서 일관성: 해당 없음 (순수 리팩토링)
누락 예외처리: 없음
기획서 정정:   없음
Gemini 반영:   미진행
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
