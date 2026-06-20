## 2026-04-26 — SkillActivationRefactor + CombatInfra + SkillSystemArch
keywords: [CommitAbility, KHS_DEBUG-recurring, hardcoding-5th-recurrence, UPROPERTY-GC-RESOLVED, EndAbility-RESOLVED, ISkillEffectInterface, GET_WORLD_SUBSYSTEM-semicolon]
status:   🔴미숙 (CommitAbility NEW, KHS_DEBUG 3회차, 하드코딩 5회차) | 🟢개선됨 (UPROPERTY GC, EndAbility 경로)
score:    정합:5 GAS:3 메모리:5 OOP:5 컨벤션:3 /5
report:   _Design/Learning/reports/LR_SkillRefactor_v1.md

---

## 2026-04-15 — PassiveSlotUI
keywords: [ensureMsgf-nullptr-guard, include-path-case-sensitivity, LoadSynchronous-UPROPERTY-GC, UpdateSlot-icon-null-defense, NativeOnInitialized, UPROPERTY-GC-tracking]
status:   🟡심화필요 (UPROPERTY/NativeOnInitialized RESOLVED, ensureMsgf/include 신규 진입)
score:    기획서정합:4 UMG:4 메모리:5 OOP:4 컨벤션:4 /5
report:   _Design/Learning/reports/KnowledgeCheck_2026-04-15_PassiveSlotUI.md

---

## 2026-04-08 — SR-FULL (전체 아키텍처 리뷰)
keywords: [UPROPERTY-TMap-GC, hardcoding-4th-recurrence, USTRUCT-defaults, Template-Method-Pattern-Enemy, constexpr-type-mismatch, AddDynamic-PC-guard, LoadRequiredClass-duplication, FEnemyRangedParams]
status:   🔴미숙 (하드코딩 4회차 미해결, UPROPERTY TMap 3회차 미해결)
score:    아키텍처:4 일관성:4 중복:3 기술부채:3 /5 (종합 3.5)
note:     아키텍처 기반 견고(Clean Arch 위반 없음). Enemy 측 추상화 부재 신규 발견. 하드코딩/UPROPERTY 반복 패턴 잔류. AddDynamic은 위젯 레벨 해결됐으나 PC 레벨 미적용.
report:   _Design/Learning/reports/LEARN_20260408_SRFULL.md

---

## 2026-04-07 — MODULE7Debug
keywords: [UE_LOG-Verbose-filtering, Instigator-pattern, FTransform-Scale-trap, AutoPossessAI, TWeakObjectPtr-lambda, YAGNI, custom-collision-channel]
status:   🟡심화필요
score:    정합:N/A GAS:N/A 메모리:N/A OOP:N/A 컨벤션:N/A (SR 없음 — 디버깅 세션)
note:     KHS_DEBUG 에디터 필터링 실전 고리 누락(애매해). Instigator 방향 직관은 맞았으나 API 연결 부재. FTransform Scale 함정 이미 알고도 걸림. YAGNI / 커스텀 채널 즉답 ✅
report:   _Design/Learning/reports/LEARN_20260407_MODULE7Debug.md

---

## 2026-03-31 — UE5BuildSetup
keywords: [UENUM-generated-h, DeveloperSettings-module, git-core-quotepath, UBT-Korean-filename-crash]
status:   🟡심화필요
note:     ① UENUM 있는 .h는 반드시 .generated.h 포함 ② UDeveloperSettings 쓰면 Build.cs에 "DeveloperSettings" 추가 ③ 한글 파일명 프로젝트엔 git config core.quotepath false 필수 (UBT가 octal 이스케이프 경로 파싱 시 .NET 크래시)

---

## 2026-03-27 — InputMode
keywords: [SetInputMode, SetShowMouseCursor, SetConsumeCaptureMouseDown, Slate-input-capture, diagnosis-order, git-diff-as-debug-tool]
status:   🔴미숙 (첫 진단 오류 — GAS 내부로 잘못 진입, 진입점 확인 생략)
score:    정합:N/A GAS:N/A 메모리:N/A OOP:N/A 컨벤션:N/A (SR 없음 — 자기주도 학습)
note:     삭제 편향(분기 검토 없는 한 줄 제거), 진단 순서 미준수, git diff 미활용 3가지 패턴 확인
report:   _Design/Learning/reports/LEARN_20260327_InputMode.md

---

## 2026-03-27 — UMGWidgetLifecycle
keywords: [NativeConstruct, NativeOnInitialized, AddDynamic, widget-caching, duplicate-binding]
status:   🔴미숙 (NativeOnInitialized 미사용 → 중복 바인딩 버그 발생, 수정 완료)
score:    정합:N/A GAS:N/A 메모리:N/A OOP:N/A 컨벤션:N/A (SR 없음 — 자기주도 학습)
report:   _Design/Learning/reports/LEARN_20260327_UMGWidgetLifecycle.md

---
