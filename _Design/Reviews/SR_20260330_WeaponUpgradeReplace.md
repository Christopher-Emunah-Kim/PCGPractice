# [SR] 2026-03-30 WeaponUpgrade_Replace

## 리뷰 대상
PLAN: PLAN_WeaponUpgrade_Replace_v1.0
변경 파일:
- GameDataSubsystem.h/.cpp
- EquipmentSubsystem.h/.cpp
- RSPlayerController.h/.cpp
- LevelUpWeaponSelectWidget.cpp
- WeaponReplaceWidget.h/.cpp (신규)
- RSSkillData.h
- GA_ProjectileAttack.cpp / GA_SummonBase.h/.cpp

---

## 반복 패턴 점검
- UPROPERTY 누락: 2회 이상 지적 → 이번 GDS UPROPERTY() 적용 확인됨 ✓ IMPROVED
- 하드코딩: 3회 연속 지적 → 이번 SLOT_COUNT = constexpr 3, 하드코딩 수치 없음 ✓ IMPROVED
- NativeOnInitialized AddDynamic: 취약패턴 사전 반영 확인됨 (WeaponReplaceWidget 24~29라인) ✓ RESOLVED

---

## 통과 항목
- GDS UPROPERTY() 일관성: LoadedWeaponDamageCurveTable UPROPERTY() 적용 정상
- GetWeaponDamageFromCurve fallback: CurveTable null 시 0.f 반환 + KHS_WARN 로그 방어
- EquipWeapon 강화 판정 우선순위: 강화 → 빈슬롯 → 슬롯가득 순서 기획서 일치
- WeaponReplaceWidget: NativeOnInitialized에 AddDynamic 배치 (취약 패턴 선제 방지)
- ClearSlot 헬퍼 분리: UpgradeWeapon에서 재사용 구조 확인
- OnSlotFull 델리게이트: UPROPERTY BlueprintAssignable 적용 정상
- RSPlayerController EndPlay: OnSlotFull.RemoveDynamic 정상 정리

---

## HIGH 이슈 — 결정 기록

### HIGH#1 — EquipWeapon 강화 체크 시 IncomingData 미사용
파일: EquipmentSubsystem.cpp:88~105
상황: GDS->GetWeaponData(WeaponID, IncomingData) 조회 후 IncomingData.BaseType과 SlotData.BaseType을 비교하는 구조인데, IncomingData는 BaseType 비교에만 쓰이고 NextLevelWeaponID는 SlotData 기준으로만 처리. WeaponID(들어오는 카드)의 NextLevelWeaponID를 쓰지 않는 것이 의도적인 설계인지 불분명.
결정: 기획 설계 확인 결과 — 강화는 "현재 슬롯 무기의 다음 레벨"로 올리는 구조. 들어오는 WeaponID는 BaseType 일치 트리거 역할만 함. IncomingData는 비교용으로만 사용하는 것이 올바른 설계. 의도적 결정으로 기록.

### HIGH#2 — OnWeaponSlotFull 에서 TimeDilation 제어 없음
파일: RSPlayerController.cpp:242~265
상황: OnWeaponCandidatesReady(레벨업 UI)에서는 TimeDilation = 0.f 로 일시정지하는데, OnWeaponSlotFull(교체 UI)에서는 TimeDilation 설정 없이 Widget을 바로 오픈. PLAN MODULE-7의 "SetPause(true) + SetInputMode UI + SetShowMouseCursor(true)" 스펙과 불일치.
결정: A) 다음 세션 수정 — 교체 UI 오픈 시 TimeDilation = 0.f 추가 필요. TODO DEFERRED 기록.

### HIGH#3 — CurveTable RowName 규칙 문서 오류
파일: PLAN_WeaponUpgrade_Replace_v1.0.md SCHEMA 섹션
상황: "RowName 규칙: BaseWeaponID (Lv1 ID 기준)"으로 기술되어 있으나 실제 코드(GetWeaponDamageFromCurve 212라인)는 EWeaponBaseType DisplayName(예: FIRESTAFF)으로 CurveTable 조회함. 코드와 문서 불일치.
결정: A) PLAN 문서 수정 완료 (이번 세션에서 처리) — RowName 규칙을 "EWeaponBaseType DisplayName 기준 (예: FIRESTAFF, ICESTAFF)"으로 수정.

---

## 개선 제안

[MED] RSPlayerController.cpp:245~248 — OnWeaponSlotFull에서 위젯 오픈 실패 시 LevelUpSys->NotifyWeaponSelectCompleted() 호출이 부적절. 교체 UI 흐름과 레벨업 흐름을 혼용하는 fallback. 슬롯가득 흐름 전용 에러 처리 경로 분리 권장.

[LOW] EquipmentSubsystem.cpp:141~149 — StopAllFire()에서 GetGameInstance()->GetWorld()로 World를 간접 조회. UGameInstanceSubsystem에서 GetWorld()를 직접 호출 가능하므로 체인 단축 권장.

[LOW] WeaponReplaceWidget.cpp:65 — 반복 순회 상한 3이 하드코딩. SLOT_COUNT를 직접 참조하거나 EQS->GetSlotCount()를 사용하면 슬롯 수 변경 시 연동 가능.

---

## 평가
기획서정합:4/5 | GAS:5/5 | 메모리:5/5 | OOP:4/5 | 컨벤션:4/5

- 기획서정합 -1: HIGH#2 TimeDilation 누락 (교체 UI 일시정지 스펙 미적용)
- OOP -1: OnWeaponSlotFull fallback에 레벨업 subsystem 혼용
- 컨벤션 -1: WeaponReplaceWidget 슬롯 상한 하드코딩 3

---

## 미결 항목
| 이슈 | 상태 | 비고 |
|------|------|------|
| HIGH#1 IncomingData 설계 확인 | RESOLVED | 의도적 설계 확인 |
| HIGH#2 TimeDilation 교체UI 누락 | DEFERRED | TODO P1 추가 |
| HIGH#3 RowName 문서 오류 | RESOLVED | PLAN 문서 수정 완료 |
