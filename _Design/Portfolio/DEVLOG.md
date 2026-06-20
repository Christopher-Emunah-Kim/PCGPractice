# DEVLOG — RoastStaffGAS 기술 의사결정 로그
> 포트폴리오·기술문서용. 파이프라인(PLAN/CODE/SR)에서 자동 기록.
> 독자: 면접관, 팀장, 채용 담당자 — 기술 판단력을 보여주는 서사 중심.

## 기록 기준 (아래 중 하나 해당 시만 기록)
- 선택지 2개 이상을 실제로 검토한 설계 결정
- 버그 원인이 즉각 자명하지 않았던 경우 (진단 과정 포함)
- 성능·메모리·구조 트레이드오프가 명확히 존재
- UE/GAS/C++의 비자명한 패턴 활용 (UPROPERTY 생명주기, ASC 소유권 등)

## 타입
| 타입 | 의미 |
|------|------|
| `ARCH` | 구조/설계 결정 — 클래스 책임 분리, 시스템 경계 |

---

## [2026-05-09] ARCH — UI 시스템: UIManagerSettings 기반 ID-레이어 분리

**배경 (이전 프로젝트 대비)**
이전 프로젝트에서는 4계층 레이어 구조 + 인스턴스 캐싱으로 GC 스파이크를 제거하고 위젯 생명주기를 중앙화했다. 이번 프로젝트에서는 그 구조를 기반으로 **"레이어 매핑 정보가 코드에 있어야 하는가"** 라는 다음 질문을 마주쳤다.

**문제**: 기존 `OpenUI<T>()` 패턴은 호출자가 위젯 클래스 타입과 레이어를 모두 알아야 한다. UI가 추가될 때마다 C++ 오픈 로직이 생겨, UI를 추가할 때마다 코드 수정이 불가피했다. 레이어 정보 역시 `Widget->UILayer`에서 읽어오는 구조라 위젯 자체와 호출자 양쪽에 책임이 분산됐다.

**검토한 선택지**:
- A) 기존 `OpenUI<T>()` 유지 + 레이어 enum을 호출자가 명시적으로 전달 — 타입 안전성은 높아지지만 호출부 결합도 증가. UI가 늘수록 호출 코드가 파편화.
- B) `UDeveloperSettings` 상속 `UUIManagerSettings`를 Project Settings에 노출, `EUIID → WBP 클래스(Soft 참조)` + `EUIID → EUILayer` Map을 에디터에서 관리 — 런타임 코드 변경 없이 UI 추가 가능. 기존 API는 하위 호환 유지.

**결정**: B 채택. `CheckUILayerSetting()`이 설정을 읽어 레이어를 결정, `HandleWidgetByLayer()`가 분기 처리. 호출자는 `EUIID`만 넘기면 된다. 기존 `OpenUI<T>()` 경로는 그대로 유지해 이미 작성된 호출 코드는 수정 불필요.

**결과**: UI 추가 시 에디터 Map 1행 추가로 완결. `ARSPlayerController`에서 `TSubclassOf` 프로퍼티 직접 참조가 전부 제거됨.

**설계상 이점**
- **코드-데이터 경계 명확화**: 어떤 UI가 어느 레이어에 속하는지는 코드 관심사가 아님. 레이어 분기 로직은 고정, 매핑 데이터는 에디터 소관.
- **호출자 책임 최소화**: 호출 측은 `EUIID`만 알면 되고, 클래스 타입·레이어 결정·캐시 여부는 서브시스템이 전담.
- **기존 API 완전 유지**: `OpenUI<T>()` 클래스 기반 경로는 그대로 존재해 레거시 호출 코드 수정 불필요.

**포트폴리오 포인트**: `UDeveloperSettings`는 `Config=Game`으로 선언하면 `.ini`에 저장되어 빌드 없이 에디터에서 편집 가능. UI 등록을 코드 밖으로 분리하는 데이터 드리븐 패턴의 UE 관용구적 구현.

**관련 파일**: `UIManagerSettings.h`, `UIManagerSubsystem.h/.cpp`, `RSPlayerController.cpp`

---

## [2026-05-06] BUG_FIX — GameInstanceSubsystem 재진입 이중 구독 패턴: bIsInitialized 가드의 함정

**상황**: HawkEye로 스테이지 플레이 후 로비로 복귀, Painter로 재진입하면 EXP가 전혀 들어오지 않는 버그 발견. 첫 플레이에선 정상 동작했기 때문에 초기화 코드 자체는 문제없다고 판단하기 쉬운 케이스.

**문제·과제**: `LevelUpSubsystem`은 `GameInstanceSubsystem`이라 레벨 전환 후에도 메모리가 유지된다. `InitializeSubsystem()` 상단의 `bIsInitialized` 가드가 2회차 진입 시 재초기화 전체를 차단 → `OnEXPChangedDel.AddDynamic` 미실행 → EXP 어트리뷰트 변화를 받지 못함. 추가로, `PlayerAttributeSet`은 `PlayerState`에 귀속되어 마찬가지로 레벨 전환 후에도 유지되므로, `RemoveDynamic` 없이 재초기화를 허용하면 2회차에 `OnEXPChanged`가 2회 발화되는 이중 구독 버그가 함께 잠복해 있었다.

**검토한 선택지**:
- A) `bIsInitialized` 가드 제거 + 매 호출마다 기존 바인딩 해제 후 재바인딩 — 단순하지만 호출 횟수 제어가 외부 의존이 되고 중복 호출 방어가 없어짐.
- B) `DeinitializeSubsystem()` 추가, `RSGameMode::OnResultConfirmed()`에서 호출 — `EquipmentSubsystem`이 이미 동일 패턴으로 구현되어 있어 구조적 일관성 확보. `RemoveDynamic`으로 이중 구독도 동시 차단.

**결정**: B 채택. `EquipmentSubsystem::DeinitializeSubsystem()` 패턴 그대로 적용. `OnResultConfirmed()`에서 Equip → LevelUp 순으로 해제.

**결과**: 캐릭터 전환 후 재진입 시 EXP 정상 수령 확인. 이중 구독 버그 사전 차단.

**포트폴리오 포인트**: `GameInstanceSubsystem`은 레벨 전환 후에도 살아있다. `bIsInitialized` 가드 패턴은 재진입 씬에서 "구독 누락"과 "이중 구독" 두 가지 버그를 동시에 만들 수 있다. GISubsystem에 상태·구독을 보유하는 경우 반드시 대칭적인 Deinitialize가 필요하다.

**관련 파일**: `LevelUpSubsystem.h/.cpp`, `RSGameMode.cpp`

---

## [2026-05-06] ARCH — UI 일시정지 상태 판별: bPausesGame 플래그 + IsAnyPausingUIOpen 패턴

**상황**: WeaponSelectWidget(레벨업/무기교체 UI) 열림 중 `TimeDilation=0`으로 게임을 멈췄지만, SlotWidget 쿨타임 타이머 감소와 캐릭터 마우스 에임 회전이 계속되는 버그 발견.

**문제·과제**: `NativeTick`의 `InDeltaTime`은 Slate 프레임 시간 기준이라 `TimeDilation` 영향을 받지 않음. `PlayerTick` 역시 `TimeDilation=0`과 무관하게 매 프레임 실행됨. "일시정지 중인가"를 각 소비자(PC, SlotWidget)가 어떻게 판별할 것인가가 설계 과제.

**검토한 선택지**:
- A) `PlayerController`에 `bIsUIOpen` 멤버 변수 추가 — PC가 UI 상태를 직접 추적. 단, PC가 이미 `OnCardPoolReady`/`OnWeaponSlotFull`로 UI 오픈을 알고 있어 중복 관리가 되고, UI 종류가 늘면 동기화 버그 온상이 됨.
- B) `UIManagerSubsystem`에 `EUIID` 목록 하드코딩 — 단순하지만 UI 추가 시 코드 수정 필요. 확장성 없음.
- C) `RSBaseWidget`에 `bPausesGame` 플래그 추가 + UMS `IsAnyPausingUIOpen()` 쿼리 — 기존 `bIsModal` 패턴과 동일 구조. WBP에서 BP 체크박스 하나로 선언적 설정, 코드 변경 없이 확장 가능.

**결정**: C안 채택. 상태의 단일 진실 공급원은 UMS, 의도 선언은 WBP에서. `IsAnyPausingUIOpen()`은 `PopupUIStack.ContainsByPredicate`로 구현해 `bIsModal` 판별 패턴과 완전히 동일한 형태.

**결과**: 일시정지 UI 열림 중 쿨타임 타이머 동결 + 캐릭터 회전 중단 정상 동작 확인.

**포트폴리오 포인트**: UI 상태를 소비자(PC, Widget)가 직접 추적하지 않고 중앙 시스템(UMS)에 쿼리하는 패턴. `TimeDilation`과 Slate `InDeltaTime`이 독립된 시간 흐름임을 실전에서 확인. `bIsModal`과 동일 구조로 일관성 있는 확장성 확보.

**관련 파일**: `RSBaseWidget.h`, `UIManagerSubsystem.h/.cpp`, `RSPlayerController.cpp`, `WeaponSlotWidget.cpp`, `CharacterSkillSlotWidget.cpp`

---

## [2026-05-06] BUG_FIX — GAS InstancedPerActor + CastingMontage: OnBlendOut 누락으로 GA 좀비 상태

**상황**: 스킬 1~6번 정상 작동하다가 플레이 중반부터 특정 스킬만 쿨타임은 시작되는데 실제 GA 발동·애니메이션 재생이 안 되는 현상 재현. 처음엔 잘 되다가 "중간부터" 안 된다는 점이 핵심 단서.

**문제·과제**: `TryActivateAbility` 반환값 추적 → FAIL 확인. `GA_Base.CommitAbility` 실패 로그 없음 → `ActivateAbility` 진입 자체 안 됨. 원인: `AbilityTask_PlayMontageAndWait`에 `OnBlendOut` 콜백 미등록. 몽타주 블렌드 아웃 구간 진입 시 `OnCompleted`/`OnCancelled`/`OnInterrupted` 중 아무것도 발화하지 않는 케이스가 존재 → `EndAbility` 미호출 → GA IsActive 상태 유지(좀비) → 이후 `TryActivateAbility`가 GAS 내부에서 재발동 차단.

**검토한 선택지**:
- A) `OnBlendOut`에 동일 콜백 바인딩 — 블렌드 아웃 시점에도 `EndAbility` 보장. `OnCompleted`와 이중 발화되지만 GAS 내부에서 중복 `EndAbility` 방어하므로 안전. (채택)
- B) `CastingMontage` null로 비우기 — 몽타주 없이 즉발로 변경. 연출 포기 필요.

**결정**: A 채택. `OnBlendOut.AddDynamic(this, &UGA_CharacterSkill::OnCastingMontageEnded)` 한 줄 추가.

**결과**: FAIL 로그 소멸. 모든 스킬 반복 사용 시 GA 정상 재발동 확인.

**포트폴리오 포인트**: GAS `InstancedPerActor` 정책에서 `EndAbility` 누락이 재발동을 영구 차단하는 패턴. `TryActivateAbility` 반환값 로깅으로 `CommitAbility` 실패 vs `TryActivate` 단계 구분하여 원인을 좁힌 디버깅 프로세스. `AbilityTask_PlayMontageAndWait`의 `OnBlendOut`은 `OnCompleted`와 별개 이벤트임을 실전에서 확인.

**관련 파일**: `GA_CharacterSkill.cpp`

---

## [2026-05-04] ARCH — ChargeAndRelease GA: 몽타주 섹션 점프 + AbilityTask 이벤트 대기 2단계 구조

**상황**: 스나이프 스킬은 "버튼 누름 → 차징 루프 → 버튼 해제 → 발사"의 2단계 흐름. 기존 GA 구조(StartSkillWithMontage → HitCheck → EndAbility 단선)와 맞지 않음.

**문제·과제**: 차징 중 몽타주는 Loop 섹션을 반복해야 하고, 해제 시점에 "Shoot" 섹션으로 점프 후 투사체 스폰이 이뤄져야 함. 입력 해제 이벤트(IA_Attack Completed/Canceled)를 GA 내부에서 어떻게 수신하느냐가 핵심.

**검토한 선택지**:
- A) GA 내부에서 IA_Attack 입력 직접 바인딩 — GA와 입력 시스템 직결. 입력 취소·능력 취소 중복 처리 복잡.
- B) PlayerController가 IA_Attack 해제 이벤트를 수신 → `SendGameplayEventToActor`(Tag_ChargeRelease) → GA 내부 `AbilityTask_WaitGameplayEvent`로 수신 (채택)

**결정**: B 채택. PC가 입력 브릿지, GA가 게임플레이 이벤트 구독. `CancelAbility` override에서 `CleanupCharging`(태그 제거 + 게이지 숨김 + 타이머 클리어)을 보장해 강제 취소 경로도 방어.

**결과**: PC는 입력만 번역, GA는 게임플레이 상태만 관리. AbilityTask_WaitGameplayEvent + 타임아웃 타이머 병행으로 해제 없이도 MaxChargeTime 후 자동 발사.

**포트폴리오 포인트**: GAS 이벤트 버스를 입력-GA 간 디커플링에 활용하는 패턴. PC↔GA 의존 제거로 캐릭터 교체 시 GA 재사용 가능. AbilityTask + 타임아웃 병행으로 해제 누락 엣지 케이스까지 방어.

**관련 파일**: `GA_CharacterSkill_Charge.h/.cpp` `RSPlayerController.cpp`

---

## [2026-05-04] PATTERN — 루트 모션 허용 여부를 GA BP에서 제어: bUseRootMotion EditDefaultsOnly

**상황**: 애로우레인 스킬은 몽타주에 루트 모션(점프 이동)이 포함되어 캐릭터 캡슐이 실제로 이동해야 하는 연출이 필요. 그런데 `StartSkillWithMontage`는 모든 스킬에 일괄 `DisableMovement()`를 적용하는 구조였음.

**문제·과제**: UE5에서 루트 모션과 `DisableMovement()`를 동시에 적용하면 루트 모션이 무시됨 — 메시는 공중으로 날아가지만 캡슐(콜리전)은 제자리에 고정. 몽타주 종료 후 메시가 캡슐 위치로 순간이동하는 시각적 결함 발생.

**검토한 선택지**:
- A) DT에 `bUseRootMotion` 컬럼 추가 — 스킬별 DT 행에서 제어. 범용적이나 DT 오염 + 매핑 추가 비용.
- B) GA Blueprint에 `EditDefaultsOnly bool bUseRootMotion` 멤버 추가 — GA BP 단위로 디자이너가 직접 제어. DT 무관, 코드 변경 최소.

**결정**: B 채택. `GA_CharacterSkill`에 `UPROPERTY(EditDefaultsOnly)` 멤버 추가. `OnAbilityActivated`에서 `!bUseRootMotion`을 `bLockMovement`로 전달 — `true`이면 `DisableMovement()` 생략하여 루트 모션이 캡슐까지 이동시키도록 허용.

**결과**: 애로우레인 GA BP에서 체크박스 하나로 제어. 다른 스킬은 기본값 `false` 유지로 기존 동작 완전 보존.

**포트폴리오 포인트**: UE5 루트 모션과 CharacterMovement `DisableMovement()`의 충돌 관계 이해. 설계 계층(DT/GA BP/코드) 중 적절한 책임 위치 판단 — 연출 제어는 디자이너 영역(GA BP)에 위임.

**관련 파일**: `GA_CharacterSkill.h/.cpp`

---

## [2026-05-03] BUG_FIX — DisableMovement + LaunchCharacter 충돌: 몽타주 세팅 후 백스텝샷 이동 불가

**상황**: 호크아이 BackstepShot GA가 `LaunchCharacter`로 뒤로 날아가는 동작을 구현. 몽타주 없이 테스트할 때는 정상 동작했으나, CastingMontage를 세팅하자 캐릭터가 전혀 날아가지 않음.

**문제·과제**: `StartSkillWithMontage`가 내부적으로 `UCharacterMovementComponent::DisableMovement()`를 호출함. UE5의 `LaunchCharacter`는 MovementMode가 `MOVE_None`(DisableMovement 상태)일 때 속도 설정 자체를 무시하는 조건이 있음. 몽타주 없이 테스트할 때는 이 경로를 거치지 않아 버그가 숨어있었음.

**검토한 선택지**:
- A) `StartSkillWithMontage`에서 DisableMovement 호출 제거 — 몽타주 재생 중 이동 가능해져 다른 스킬에 영향
- B) `ExecuteEffect_BackstepShot` 내부, `LaunchCharacter` 직전에 `SetMovementMode(MOVE_Falling)` 복원 (채택)

**결정**: B안 채택. 복원 대상을 MOVE_Falling으로 지정 — MOVE_Walking은 지면 스냅이 발생해 발사 직후 즉시 고정될 수 있음. LaunchCharacter 이후 착지 시 CMC가 자동으로 MOVE_Walking 복원.

**결과**: CastingMontage 유무에 관계없이 BackstepShot 이동 정상 동작. DisableMovement는 몽타주 재생 중 일반 이동 차단 용도로 유지됨.

**포트폴리오 포인트**: UE5 CharacterMovementComponent의 비문서적 동작 — DisableMovement(MOVE_None) 상태에서 LaunchCharacter가 무시됨. 독립적으로 설계된 두 시스템(몽타주 캐스팅 잠금 / 물리 발사)의 상태 충돌을 진단한 케이스.

**관련 파일**: `GA_CharacterSkill.cpp` `ExecuteEffect_BackstepShot`

---

## [2026-05-03] PATTERN — SpawnFX 재생 완료 후 게임플레이 효과 시작: EditDefaultsOnly 딜레이 타이머

**상황**: ChainTrap 스킬의 `BP_ChainTrapActor`에서 소환 FX(SpawnFX)가 시각적으로 완성된 시점에 실제 수렴 Pull 효과가 시작되어야 연출이 자연스러움. FX 재생 중에 적이 끌려오면 "아직 뭔가 나오는 중인데 이미 끌려감" 어색함이 발생.

**문제·과제**: FX와 게임플레이 타이밍을 동기화하는 방법 선택.

**검토한 선택지**:
- A) `UNiagaraComponent::OnSystemFinished` 콜백 — 정확하지만 루핑 Niagara 시스템에서는 OnSystemFinished가 발동하지 않음
- B) `SpawnFXDuration` EditDefaultsOnly 딜레이 타이머 — BP에서 FX 재생 시간과 일치시키는 명시적 계약 (채택)

**결정**: B안 채택. `SpawnFXDuration = 2.0f` 기본값을 `EditDefaultsOnly`로 노출해 BP에서 FX 타이밍에 맞게 조정 가능. SpawnFXDelayHandle 타이머 만료 후 PullTimerHandle + DurationTimerHandle 동시 시작.

**결과**: SpawnFX 재생 2초 후 수렴 시작 → Duration 만료 시 BurstFX + 데미지/기절 GE Apply. 연출 타이밍이 FX와 자연스럽게 일치.

**포트폴리오 포인트**: Niagara 이벤트 콜백의 한계(루핑 FX)를 파악하고 BP-exposed 딜레이 타이머로 대체하는 패턴. `SpawnFXDuration`이 FX 재생 시간의 "명시적 계약"이 되어 디자이너가 C++ 없이 타이밍 조정 가능.

**관련 파일**: `ChainTrapVortexActor.h/.cpp`

---

## [2026-05-03] ARCH — GAS ExecCalc + Duration GE 혼재 금지: 데미지·기절 GE 분리

**상황**: ChainTrap 스킬의 기절 GE(`GE_Stun`, Duration 타입)에 `RS_DamageExecCalc`를 붙여서 기절과 데미지를 하나의 GE로 처리하려 했음. 테스트에서 데미지가 들어가지 않아 원인 분석.

**문제·과제**: `RS_DamageExecCalc`가 Duration GE에서 왜 동작하지 않는지, 그리고 동작한다 해도 안전한지 검증.

**검토한 선택지**:
- A) Duration GE에 ExecCalc 유지 — UE5는 Duration GE의 ExecCalc를 Instant로 1회 실행하지만 SetByCaller 읽기 타이밍·다중 Apply 시 중복 데미지 위험
- B) Instant GE(데미지) + Duration GE(기절 태그) 분리 (채택)

**결정**: B안 채택. `GE_Hawkeye_ChainTrap_Damage`(Instant + ExecCalc + SetByCaller)와 `GE_Hawkeye_ChainTrap_Stun`(Duration, CC.Stun 태그 부여만)으로 분리. `ApplyEffectsToTargets`에서 데미지 먼저, 기절 나중 순서로 Apply.

**결과**: 데미지와 기절이 독립적으로 명확히 동작. GE_Stun은 다른 스킬에서도 재사용 가능한 범용 CC GE로 정착.

**포트폴리오 포인트**: GAS ExecCalc 설계 원칙 확립 — "ExecCalc는 Instant Policy GE에만". Duration GE에 ExecCalc를 혼재하면 다중 Apply 시 의도치 않은 반복 데미지 위험이 있음을 실제 케이스로 검증.

**관련 파일**: `ChainTrapVortexActor.cpp` `ApplyEffectsToTargets` / `GE_Hawkeye_ChainTrap_Damage` / `GE_Stun`

---

## [2026-04-27] PATTERN — GA Lerp 이동 중 외부 취소 방어 패턴

**상황**: BackstepShot GA가 `DisableMovement` 후 0.016s 루프 타이머로 Lerp 이동을 수행하는 중, 피격·CC 등으로 GA가 외부에서 강제 종료될 수 있음.

**문제·과제**: Lerp 완료 콜백에서만 `RestoreMovement`를 호출하면, GA가 취소될 때 타이머는 정리되지만 이동 잠금이 영구 유지되어 캐릭터가 조작 불능 상태가 됨.

**검토한 선택지**:
- A) `OnCancelled` 델리게이트 별도 바인딩 — 취소 경로만 커버, 정상 종료 경로와 중복 처리 발생
- B) `EndAbility` override — 취소/정상 모든 경로가 단일 진입점 통과 (채택)

**결정**: `EndAbility` override에 `bLerpInProgress` 플래그 체크를 추가. 플래그가 true이면 타이머 강제 정리 + `RestoreMovement` 보장 후 `Super::EndAbility` 호출. 정상 완료 경로(콜백)는 `bLerpInProgress = false` 설정 후 `EndAbility`를 호출하므로 override 내부 정리 로직이 실행되지 않음.

**결과**: 피격·CC·몽타주 중단 등 어떤 경로로 GA가 종료되더라도 `DisableMovement` 고착 버그 방지. 타이머 기반 비동기 동작을 가진 GA의 방어 패턴으로 정착.

**포트폴리오 포인트**: GAS EndAbility override를 이용한 비동기 상태 정리 패턴 — 타이머+이동잠금이 항상 쌍으로 해제되는 구조를 단일 진입점으로 보장.

**관련 파일**: `GA_CharacterSkill.h/.cpp`

---

## [2026-04-26] ARCH — 스킬 발동 타입 2축 분리 및 DT 통폐합 설계 결정

**상황**
캐릭터 스킬 시스템이 성장하면서 `ESkillActivationType` 단일 Enum이 조준방식과 효과방식을 동시에 표현하게 됨. `ExecuteSpawnPreview` 함수 하나가 텔레포트 / 범위 피해 / 장판 Actor 스폰을 `if/else` 체인으로 처리하고, `bTeleportOnConfirm` 같은 BP 플래그로 땜질하는 상황까지 진행됨. 또한 캐릭터 스킬 데이터가 5개 테이블에 분산되어 GDS가 `SkillEffectID` FK로 복합 조회하는 구조.

**문제·과제**
새 캐릭터(호크아이) 스킬 6개를 추가하기 전, 같은 패턴이 반복되면 Execute 분기가 통제 불가능해지는 시점이 예측됨. 특히 `SpawnPreview + 텔레포트` / `SpawnPreview + 장판` / `SpawnPreview + 범위AoE` 처럼 동일 조준방식에서 결과만 다른 스킬들이 늘어날수록 타입 폭발 문제 발생.

**검토한 선택지**
- A안: 2축 분리 (TargetingType × EffectType) + DT 통폐합 — 근본 해결, 리팩터링 비용 높음
- B안: GA 분리 유지 + DT 중복 컬럼만 정리 — 범위 작지만 소서리스/호크아이 추가 시 동일 문제 재발
- SoftPtr 리소스 전용 DT 분리 (`DT_CharacterSkill_Resource`) — 스킬 30개+ 시점에 유효하나 지금은 오버엔지니어링

**결정**
A안 채택. 3축(`ESkillTargetingType` × `ESkillEffectType` × `EProjectileMoveType`) + `ESkillSpawnPattern` 추가. DT_CharacterSkill 단일 완결 구조(스탯 그룹 / SoftPtr 리소스 그룹 주석 구분). 무기 스킬 분산 테이블은 무기 스킬 전용으로 격리 유지. SoftPtr 분리는 스킬 30개+ 시점에 재검토.

**결과**
GA Execute 함수가 `ResolveTargeting(TargetingType) → ResolveEffect(EffectType)` 2단계 분기로 단순화. 새 스킬 추가 시 C++ 신규 타입 없이 DT 데이터만으로 처리 가능한 구조 확보.

**포트폴리오 포인트**
단순 기능 추가가 아닌 확장성 문제를 선제적으로 감지하고, 새 캐릭터 착수 전 리팩터링 시점을 선택한 설계 판단. "같은 동작방식에서 다른 결과를 내는 것마다 타입을 만드는 것이 잘못된 설계"라는 원칙을 실제 코드 구조에 적용.

**관련 파일**
`EnumTypes.h` / `DataTableStructs.h` / `RuntimeDataStructs.h` / `GA_CharacterSkill.h/.cpp` / `GameDataSubsystem.cpp`

---

## [2026-04-26] BUG_FIX — Pierce 투사체 첫 타격 즉시 소멸

**UE_Ver**: 5.4
**Knowledge_Risk**: LOW

**상황**
`ESkillActivationType` → 3축 리팩터링 과정에서 `GA_CharacterSkill`의 투사체 조립 함수(`BuildProjectileInitData`)를 신규 작성. 도화가 4번 범가르기(Pierce 타입)가 관통하지 않고 첫 타격 후 즉시 소멸하는 버그 발생.

**문제·과제**
`BaseProjectile::HandlePierceHit`의 종료 조건이 `PierceHitCount >= PierceCount`인데, `FProjectileInitData.PierceCount` 기본값이 0. 첫 타격 시 `PierceHitCount`가 1이 되는 순간 `1 >= 0` 조건 성립 → 즉시 `ReturnToPool`. 원인은 `BuildProjectileInitData`에서 `PierceCount` / `DamageDecay` 필드를 `ExecData`로부터 주입하는 코드가 누락된 것.

**검토한 선택지**
- A안: `constexpr int DEFAULT_PIERCE_COUNT = 10`을 헤더에 두고 Pierce 타입 기본값으로 하드코딩
- B안: `FCharacterSkillStaticData` / `FCharacterSkillExecData`에 `PierceCount` / `DamageDecay` 필드 추가 + CSV 컬럼화

**결정**
B안 채택. 호크아이 래피드샷도 Pierce 타입이고 스킬마다 관통 횟수가 다를 수 있음. 하드코딩은 데이터 드리븐 원칙 위반. CSV 컬럼 추가 비용이 낮아 B안이 명확히 우위.

**결과**
`BuildProjectileInitData`에서 `InitData.PierceCount = FMath::Max(1, ExecData.PierceCount)` 주입. Pierce 스킬 3종(도화가04, 호크아이01, 호크아이06)에 `PierceCount=10` 설정.

**포트폴리오 포인트**
리팩터링 중 데이터 흐름 단절 버그 진단 — `FProjectileInitData` 기본값 함정을 추적하고, 즉각 수정보다 데이터 드리븐 원칙을 우선해 필드를 확장한 판단.

**관련 파일**
`DataTableStructs.h` / `RuntimeDataStructs.h` / `GameDataSubsystem.cpp` / `GA_CharacterSkill.cpp` / `BaseProjectile.cpp:416`

| `BUG_FIX` | 비자명한 버그 — 원인 진단 과정이 핵심 |
| `OPT` | 성능·메모리 최적화 — 측정 가능한 개선 |
| `REFACTOR` | 구조 개선 — 기능 변화 없이 설계 품질 향상 |
| `PATTERN` | UE/GAS/C++ 특화 패턴 발견 및 적용 |

---

## 항목 형식
```
## [YYYY-MM-DD] [TYPE] 제목

**UE_Ver**: 5.x
**Knowledge_Risk**: LOW | MEDIUM | HIGH
  LOW    — 학습 데이터 내 안정 API
  MEDIUM — cutoff 근처, 다음 버전 업 시 재검증 권장
  HIGH   — cutoff 이후 API, 반드시 재검증

**상황**: 어떤 맥락에서 이 결정이 필요했나
**문제/과제**: 정확히 무엇을 해결해야 했나
**검토한 선택지**:
  - A) ... — 장단점
  - B) ... — 장단점
**결정**: 무엇을 선택했고 왜
**결과/효과**: 실제로 어떻게 됐나
**포트폴리오 포인트**: 이 항목이 보여주는 역량
**관련 파일**: Source/... (줄번호 선택)
**검증 기준**:
  - [ ] (해당 항목이 실제로 해결됐음을 확인하는 구체적 조건)
```

## [2026-04-24] OPT Game ms 병목 진단 + 다층 Tick 최적화

**UE_Ver**: 5.4
**Knowledge_Risk**: LOW

**상황**: `stat game` 기준 Game ms 90ms 이상 (FPS 8~11). 적 웨이브 + 스킬 복합 시 더 악화. CPU 병목이 GameThread에 집중.

**문제/과제**: 무엇이 GameThread를 막고 있는지 profiler 없이 코드 레벨에서 후보를 추려 우선순위를 매겨야 했다.

**검토한 선택지**:
- A) AIC Tick 매 프레임 → 0.1s 간격 — 플레이어 위치·사망 상태 갱신은 10Hz로 충분. BB 갱신 지연 0.1s는 AI 반응에 무의미
- B) BT Component 0.2s — BT는 내부 조건 캐싱을 하므로 5Hz로도 AI 품질 유지
- C) 거리 기반 CMC/Anim Tick 간격 — 근거리 전투 품질 유지(매 프레임) + 원거리 연산 절감(10~20Hz)
- D) `VisibilityBasedAnimTickOption::OnlyTickPoseWhenRendered` — 프러스텀 밖 적 Anim 자동 중단. 싱글플레이어라 부작용 없음
- E) `TickEmissiveFade` 타이머 0.016f(60Hz) → 0.05f(20Hz) — 피격 플래시 페이드가 60fps 필요 없음. AoE 히트 시 적 수×60 콜백이 GameThread 누적
- F) `UWidgetComponent` Screen space HPBar — 적 수만큼 Slate 위젯 독립 렌더. Shadow 연산 비활성화로 부하 절감

**결정**: A~E 전부 적용. F는 에디터 설정(Shadow off)으로 처리.
적 수 70→30 감축은 선형 비례 효과라 가장 직접적이지만, 개별 최적화가 각 적당 비용을 줄이는 근본 해결.

**결과/효과**:
| 구간 | Before | After | 개선율 |
|---|---|---|---|
| 적 대량 스폰 Game ms | 90ms (11fps) | 30ms (31fps) | -67% / FPS +183% |
| 적+스킬 복합 Game ms | 92ms (8fps) | 29ms (29fps) | -68% / FPS +240% |

**포트폴리오 포인트**: profiler 없이 코드 분석으로 병목 후보 우선순위화 → 각 컴포넌트(AIC/BT/CMC/Anim/Timer)의 틱 비용을 독립적으로 격리·측정하는 사고 방식. UE5 Tick 아키텍처(SetComponentTickInterval / VisibilityBasedAnimTickOption)를 계층별로 활용.

**관련 파일**:
- `Source/.../Enemy/EnemyAIController.h/.cpp` — AIC/BT Tick + AdjustPawnTickRates
- `Source/.../Enemy/EnemyBaseCharacter.h/.cpp` — VisibilityBasedAnimTickOption + FlashTickInterval

**검증 기준**:
- [x] stat game Game ms 30ms 이하 (적 30마리 + 스킬 복합)
- [x] 근거리 전투 이동·애니메이션 끊김 없음
- [x] 피격 이미시브 플래시 연출 정상 동작

---

## 2026-04

### [2026-04-23] [OPT] 전 구간 렌더링 병목 진단 — Ray Tracing / 동기 로딩 / GC 스파이크

**UE_Ver**: 5.4
**Knowledge_Risk**: LOW

**상황**: 포트폴리오 빌드 전 퍼포먼스 기준선 측정. stat unit / stat scenerendering / Insights로 6개 구간 프로파일링.

**Before 수치**

| 구간 | FPS | Frame | Game | Draw | GPU | Draws | Prims |
|------|-----|-------|------|------|-----|-------|-------|
| 로비 커스텀뎁스 | 8.55 | 113.52ms | 29.22 | 106.71 | 73.05 | 400 | 600.2K |
| 로딩 구간 | 8.86 | 112.90ms | 83.64 | 54.91 | 43.51 | 435 | 234.2K |
| 웨이브 시작 | 13.97 | 71.56ms | 64.70 | 57.07 | 27.18 | 614 | 957.3K |
| 스킬 이펙트 | 15.64 | 63.93ms | 61.49 | 43.14 | 17.98 | 498 | 388.3K |
| 적 대량 스폰 | 11.14 | 91.24ms | 90.78 | 36.57 | 23.15 | 1563 | 5750.7K |
| 적+스킬 복합 | 8.71 | 110.06ms | 92.22 | 109.91 | 78.88 | 1395 | 5501.9K |

**병목 원인 분류**

- **A. Hardware Ray Tracing (전 구간 공통)**: `r.RayTracing=True` + `RayTracingProxies.ProjectEnabled=True` 상태에서 Lumen은 소프트웨어 RT 경로를 쓰고 있었음 → GPU가 BVH 프록시를 불필요하게 빌드. `Ray tracing dynamic update primitives` 최대 2,719,681. Project Settings → Support Hardware Ray Tracing OFF로 해소.
- **B. 동기 에셋 로딩 (구간 2, 3)**: `FLinkerLoad::Preload` 98.2ms (SKM_Skeleton_Guard_Clothing), `GameThreadWaitForTask` 343.8ms (EnemyAI_BT_SyncLoad) → GameThread 블로킹. LoadAsync 전환 필요.
- **C. 스킬 이펙트 셰이더 (구간 4, 6)**: Shader Complexity 흰색(Extremely bad). `PullVortex_FX_SyncLoad` — 스킬 발동 시에도 동기 로딩 발생.
- **D. GC 스파이크 + 대량 스폰 (구간 5, 6)**: GarbageCollection 328.2ms 스파이크. Draws 구간 4(498) → 구간 5(1563) 3배 급증. 적 스폰이 풀에서 나오지 않고 새로 생성되는 구조 의심.

**최적화 우선순위 및 진행 상황**

| # | 작업 | 상태 | 비고 |
|---|------|------|------|
| 1 | Hardware Ray Tracing OFF | ✅ 완료 | `r.RayTracing=False` |
| 2 | 동기 로딩 → 프리로드 전환 | ✅ 완료 | SkillFX/BT 프리로드 + TransitionGameMode 버그 수정 |
| 3 | GC 스파이크 제거 | ✅ 완료 | SetWidgetClass 중복 호출 차단 → GC 블록 소멸 확인 |
| 4 | 스킬 이펙트 셰이더 (GPU) | 예정 | GPU 68ms — 다음 단계 |

**After 수치 — CPU 병목 해소 완료 (2026-04-23)**

| 구간 | Before FPS | After FPS | Before Frame | After Frame | 개선율 |
|------|-----------|-----------|-------------|------------|--------|
| 로비 커스텀뎁스 | 8.55 | 62.81 | 113.52ms | 16.94ms | **-85%** |
| 로딩 구간 | 8.86 | 26.65 | 112.90ms | 57.02ms | -50% |
| Wave_Activate | 13.97 | 18.21 | 71.56ms | 54.93ms | -23% |
| 오브젝트 풀링 | 8.86 | 9.15 | 112.90ms | 92.41ms | -18% |
| 적 대량 스폰 | 10.46 | 10.46 | 95.77ms | 95.59ms | ≈0% (Game 95.64ms 잔존) |
| 적+스킬 복합 | 8.10 | 8.10 | 120.14ms | 123.43ms | ≈0% (Game 119.81ms / GPU 68.79ms) |
| 스킬 이펙트 | 15.64 | 6.91 | 63.93ms | 144.78ms | ⚠️ 악화 (텍스처 컴파일) |

> 구간 5·6: GC 블록은 Insights에서 소멸 확인. Game ms 95~119ms 잔존 — GameThread 별도 원인 존재.
> 구간 6: GPU 68ms 본격 드러남 — CPU 병목 제거 후 GPU 병목이 가시화된 것으로 판단.
> 구간 5 스킬 이펙트 악화는 텍스처 컴파일 타이밍 문제. GPU 병목 단계에서 처리 예정.

**결과/효과**: 로비 85% / 로딩 50% / 웨이브 23% 개선. CPU GC 블록 제거 완료. 잔여 Game ms는 GameThread 다른 원인 — 프로파일링 추가 필요.

**포트폴리오 포인트**: (1) RT가 켜져 있어도 Lumen 소프트웨어 경로를 쓰면 효과는 없지만 BVH 빌드 비용은 그대로라는 비자명한 함정 진단. (2) 프리로드 경로에 에셋이 등록됐어도 `StartLevelStreaming()` 조기 호출 버그로 실제 보장이 안 됐던 케이스 — 코드 리뷰 없이 측정만으로는 발견 불가한 버그. (3) Actor 풀링은 정상이었지만 Actor에 부착된 WidgetComponent는 풀 재사용 시마다 새 인스턴스 생성 — 풀링 범위를 Actor 단위가 아니라 Actor 내 소유 UObject 전체로 검토해야 한다는 교훈.

**관련 파일**: `Config/DefaultEngine.ini` / `Core/Transition/RSTransitionGameMode.cpp` / `System/EnemySpawner.cpp` / `Character/Enemy/EnemyBaseCharacter.cpp` / `UI/Enemy/EnemyHPBarWidget.h/.cpp`

**검증 기준**:
  - [x] RT OFF 후 구간 1 Frame 85% 감소 확인
  - [x] GC 스파이크 제거 후 Insights GC 블록 소멸 확인
  - [ ] GameThread 잔여 95~119ms 원인 특정 및 추가 최적화
  - [ ] 텍스처 컴파일 완료 후 구간 5 재측정
  - [ ] GPU 병목(구간 6, 68ms) 최적화

---

### [2026-04-23] [BUG_FIX] 동기 로딩 343ms — 프리로드 코드가 있었지만 실제로는 동작하지 않았던 버그

**UE_Ver**: 5.4
**Knowledge_Risk**: LOW

**상황**: Insights에서 `GameThreadWaitForTask` 343.8ms (BehaviorTree 동기 로드), `FLinkerLoad::Preload` 98.2ms (SKM 스켈레탈 메시)가 측정됨. `RSTransitionGameMode`에 `RequestAsyncLoad` 코드가 이미 있었기 때문에 프리로드가 동작하고 있다고 가정했지만, 실제로는 BT가 첫 스폰 시점에 블로킹 로드되고 있었음.

**문제/과제**: 프리로드 코드가 존재하는데 왜 런타임에 동기 로드가 발생하는가.

**원인 진단 1 — TransitionGameMode 조기 StartLevelStreaming 버그**:
```cpp
// Before (버그): 프리로드 요청 직후 즉시 레벨 전환
GET_GI_SUBSYSTEM_FROM(URuntimeDataSubsystem, RDS, GI)
StartLevelStreaming();  // ← 비동기 로드 완료 전에 레벨 전환
RDS->GatherPreloadAssets(OutPaths, ...);
Streamable.RequestAsyncLoad(OutPaths, ...);
```
비동기 로드가 완료되기 전에 레벨이 전환되면 `StreamableHandle` 수명이 `GameMode` 소멸과 함께 끊김 → GC가 프리로드된 에셋 회수 → 첫 스폰 시 재로드.
`StartLevelStreaming()` 단독 호출 한 줄 제거로 수정. 이후 비동기 로드 완료 콜백에서만 레벨 전환.

**원인 진단 2 — BT가 프리로드 목록에 없었음**:
`FEnemyPreloadBundle`에 `BehaviorTree` 필드가 있었지만 `GatherPreloadAssets`에서 경로 수집 코드가 누락. `EnemySpawner::InitPools`에서 매 스폰마다 `LoadSynchronous()` 호출 → 343ms 블로킹.
수정: `GatherPreloadEnemyAssets`에 BT 경로 수집 추가 + `InitPools`에서 `BTCache(TObjectPtr<UBehaviorTree>)` 빌드 → GC 방지 강참조 유지 → 이후 `LoadSynchronous`가 FindObject 경로(0ms)로 처리.

**원인 진단 3 — SkillFX가 프리로드 목록에 없었음**:
`FCharacterPreloadBundle`이 Mesh + AnimBP만 수집. 스킬 발동 시 `EffectActorClass.LoadSynchronous()` 콜드 로드.
수정: `GameDataSubsystem::GetCharacterPreloadBundle`에서 `GetSkillsByCharacter`로 SkillFX 경로 수집, `FCharacterPreloadBundle.SkillFXList` 필드 추가.

**결과/효과**: 로딩 구간 Frame -50% (112.90ms → 57.02ms), Wave_Activate -23% (71.56ms → 54.93ms). BT 343ms 블로킹 제거.

**포트폴리오 포인트**: "프리로드 코드가 있다 = 프리로드가 동작한다"는 가정의 함정. `StreamableHandle` 수명이 `GameMode` 수명에 종속된다는 비자명한 UE 메모리 모델. 코드 리뷰나 로그만으로는 발견 불가 — Insights 계측이 없었다면 원인 미특정 상태로 넘어갔을 버그.

**관련 파일**: `Core/Transition/RSTransitionGameMode.cpp` / `Subsystems/RuntimeDataSubsystem.cpp` / `Subsystems/GameDataSubsystem.cpp` / `System/EnemySpawner.cpp` / `Data/RuntimeDataStructs.h`

**검증 기준**:
  - [x] Wave_Activate Frame -23% 확인 (71.56ms → 54.93ms)
  - [x] 로딩 구간 Frame -50% 확인 (112.90ms → 57.02ms)

---

### [2026-04-23] [BUG_FIX] GC 스파이크 117ms — Actor 풀링은 정상, WidgetComponent가 누수

**UE_Ver**: 5.4
**Knowledge_Risk**: LOW

**상황**: Insights에서 GC 블록이 반복 발생. `obj list` / Insights Timing 트랙에서 GC 직전 GameThread에 "모든 적의 HPBar 갱신 로직"만 쌓여 있음이 확인됨.

**문제/과제**: 적 Actor는 풀에서 꺼내 재사용 중 — 신규 생성이 없는데 왜 GC가 발생하는가. 풀링은 Actor 단위였지만, Actor 내부 UObject가 매번 새로 생성되고 있었다.

**원인 진단**:
`AEnemyBaseCharacter::SetupHPBar()`가 `InitializeEnemy()` 내에서 매 풀 재사용 시 호출됨.
`UWidgetComponent::SetWidgetClass()`는 호출마다 기존 위젯 참조를 끊고 `CreateWidget`으로 새 인스턴스를 생성하는 UE 내부 동작.
→ 웨이브마다 적 60마리 꺼냄 → HP바 위젯 60개 신규 생성 → 이전 60개 GC 대기 → 임계치 도달 → GC 발동.
Actor 재사용이 오히려 "풀에서 꺼낼 때마다 위젯이 폐기되는 주기적 GC"를 만들고 있었음.

**수정**:
```cpp
// Before: 매번 SetWidgetClass → 새 위젯 생성
HPBarWidgetComp->SetWidgetClass(HPBarWidgetClass);

// After: 위젯이 없을 때만 생성, 이후 재사용 시 BindToASC만 호출
if (!HPBarWidgetComp->GetWidget())
{
    HPBarWidgetComp->SetWidgetClass(HPBarWidgetClass);
}
```
`OnPoolDeactivate()`에 `UnbindFromASC()` 추가 — 반납된 위젯이 소멸된 ASC에 콜백하는 댕글링 방지.

**결과/효과**: Insights GC 블록 소멸 확인. 위젯 인스턴스 60개가 웨이브 전체에서 재사용됨.

**포트폴리오 포인트**: 풀링 효과를 Actor 단위로만 검증하면 놓치는 함정 — Actor에 부착된 WidgetComponent, 동적 컴포넌트 등 내부 소유 UObject도 풀 재사용 시 생성 비용 검토 필요. GC 원인을 "신규 스폰"이 아닌 "재사용 Actor 내부"에서 찾아낸 진단 과정.

**관련 파일**: `Character/Enemy/EnemyBaseCharacter.cpp:SetupHPBar` / `UI/Enemy/EnemyHPBarWidget.h/.cpp`

**검증 기준**:
  - [x] Insights에서 GC 블록 소멸 확인

---

### [2026-04-22] [ARCH] ElementColor 부여 책임 — Actor 자율 해석 vs GA 중앙 해석

**UE_Ver**: 5.4
**Knowledge_Risk**: LOW

**상황**: 도화가 스킬 장판(GroundEffectActor) / 흡입(PullVortexActor)에 속성 색상(ElementColor)을 Niagara FX에 주입해야 했음. 기존 `SpawnSkillFX`에는 `ElementTag → FLinearColor` 매핑 로직이 이미 구현되어 있었고, `FSkillEffectInitData`를 통해 Actor에 초기화 번들을 전달하는 구조였음.

**문제/과제**: `FSkillEffectInitData`에는 `ElementTag`만 있고 `ElementColor`가 없었음. Actor들이 `InitEffect`에서 색상을 적용하려면 Tag → Color 매핑을 어디서 수행할지 결정해야 했음.

**검토한 선택지**:
- A) 각 Actor의 `InitEffect`에서 `ElementTag → FLinearColor` 직접 해석
  — 매핑 로직 중복, `Element.Ancient` 추가 시 Actor 수만큼 수정 필요
- B) GA가 `ResolveElementColor()`로 해석 완료 → `FSkillEffectInitData.ElementColor` 전달
  — 매핑 단일화, Actor는 색을 "해석"하지 않고 "적용"만 함

**결정**: 안B. `static FLinearColor ResolveElementColor(FGameplayTag)` 헬퍼를 GA에 추가, `SpawnSkillFX` 인라인 분기도 동일 헬퍼로 교체. `FSkillEffectInitData`에 `FLinearColor ElementColor` 필드 추가.

**결과/효과**: `Element.Ancient` 추가 시 `ResolveElementColor` 한 곳만 수정. Actor는 FX 파라미터 세팅에만 집중.

**포트폴리오 포인트**: 데이터 흐름 책임 분리 — "해석자(GA)"와 "적용자(Actor)" 역할 명확화. 변경 파급 범위를 의식적으로 축소하는 설계 판단.

**관련 파일**:
  - `Source/.../GAS/Abilities/GA_CharacterSkill.h/.cpp` (ResolveElementColor)
  - `Source/.../Data/RuntimeDataStructs.h` (FSkillEffectInitData.ElementColor)
  - `Source/.../Objects/GroundEffect/GroundEffectActor.cpp`, `PullVortexActor.cpp` (InitEffect)

**검증 기준**:
  - [ ] Element.Ancient 스킬 발동 시 장판/흡입 FX가 먹자주색으로 표시됨

---

### [2026-04-22] [ARCH] PreWarm 풀 수량 정보의 분산 보유 — 책임 기반 설계 검증

**UE_Ver**: 5.4
**Knowledge_Risk**: LOW

**상황**: 스킬 이펙트 액터(PullVortexActor 등)를 PreWarm에 추가하면서, 풀 수량이 GameMode/EnemySpawner/PC에 분산되어 있는 구조가 의도된 것인지 설계 결함인지 점검이 필요했다.

**문제/과제**: `BuildPreWarmList`가 EnemySpawner, PlayerController, RuntimeDataSubsystem, GameDataSubsystem 등 여러 소스에서 데이터를 수집하는 구조. "GameMode 단일 집중"이 맞는지, "책임별 분산"이 맞는지 판단.

**검토한 선택지**:
  - A) GameMode 단일 집중 — 모든 풀 수량을 GameMode의 `EditDefaultsOnly`로 관리. 조회 지점이 하나지만, GameMode가 에너미·위젯·스킬 세부사항을 모두 알아야 해 단일 책임 위반.
  - B) 책임 기반 분산 (현재 구조) — EnemySpawner는 스테이지 구성(에너미 종류·수량)을, PC는 자신의 UI 위젯 클래스를, GameMode는 GameMode 수준 수량만 보유. `BuildPreWarmList`는 이를 "조율"하는 역할만 담당.

**결정**: B안이 올바른 설계. `BuildPreWarmList`는 데이터 소유자가 아니라 PreWarm 요청 조립자이며, 오케스트레이터인 GameMode의 책임 범위 안에 있다. 각 소유자는 자신의 도메인 안에서 값을 결정하고, GameMode는 이를 수집해 PoolingSubsystem에 위임한다.

**결과/효과**: 스킬 이펙트 액터 PreWarm 추가 시 기존 패턴을 그대로 따라 자연스럽게 확장됨. 설계 의도를 명확히 인지함으로써 이후 PreWarm 항목 추가 시 올바른 위치(소유자)에 수량을 두는 기준이 생겼다.

**포트폴리오 포인트**: 동작하는 코드에서 의도를 역추적해 설계 원칙(단일 책임, 오케스트레이터 패턴)과 대조·검증하는 사고 과정.

**관련 파일**: Source/RoastStaffGAS/Private/Core/RSGameMode.cpp (BuildPreWarmList), Public/System/EnemySpawner.h

---

### [2026-04-20] [BUG_FIX] AGroundEffectActor 충돌 활성화 타이밍 버그 — OnPoolActivate vs InitGroundEffect

**UE_Ver**: 5.4
**Knowledge_Risk**: LOW

**상황**: 장판(GroundEffectActor)이 스폰되자마자 근처 에너미에게 GE가 적용되는 버그. 로그에 "필수 데이터 누락" 경고가 찍히면서 ApplyGEToTarget이 null 체크에서 return.

**문제/과제**: 충돌 감지는 되는데 GE 적용에 필요한 ASC/GEClass 캐시가 null인 상태. 원인 진단이 필요했다.

**검토한 선택지**:
  - A) `OnPoolActivate`에서 충돌 활성화 (기존 구현) — 풀에서 꺼내자마자 충돌이 켜지므로 `InitGroundEffect` 호출 전에 이미 Overlap 이벤트 발생 가능. 에너미가 스폰 위치 근처에 있으면 InitGroundEffect 이전에 ApplyGEToTarget 호출 → 캐시 null → 조용한 실패.
  - B) `InitGroundEffect` 마지막 줄에서 충돌 활성화 — 모든 캐시 설정 완료 후 충돌을 열므로 순서 보장.

**결정**: B안 채택. `OnPoolActivate`에서는 충돌을 비활성화하고, `InitGroundEffect` 끝에서만 활성화.

**결과/효과**: "필수 데이터 누락" 로그 사라짐. 장판이 올바르게 GE를 적용.

**포트폴리오 포인트**: 풀링 패턴에서 초기화 순서(Activate → Init)와 이벤트 트리거 타이밍의 경합 조건 진단. GAS 컴포넌트의 생명주기와 UE 충돌 시스템의 상호작용 이해.

**관련 파일**: Source/RoastStaffGAS/Private/Objects/GroundEffect/GroundEffectActor.cpp

**검증 기준**:
  - [x] 장판 스폰 시 "필수 데이터 누락" 로그 미출력
  - [x] 에너미가 장판 위에 있어도 초기화 전 GE 미적용

---

### [2026-04-22] [BUG_FIX] GAS MakeEffectContext + AddInstigator null 덮어쓰기 — 데미지 0 무증상 버그

**UE_Ver**: 5.4
**Knowledge_Risk**: LOW

**상황**: PullVortexActor / GroundEffectActor에서 GE를 적용했으나 에너미 HP가 줄지 않았다. ExecCalc 로그에 데미지 계산은 정상이었으나 실제 어트리뷰트 변화 없음.

**문제/과제**: 풀링 액터(`GetInstigator() == null`)에서 `Context.AddInstigator(GetInstigator(), GetInstigator())`를 호출하면 `MakeEffectContext`가 이미 세팅한 유효한 Instigator를 null로 덮어쓴다. ExecCalc에서 SourceASC 조회 실패 → 데미지 배율 0.

**검토한 선택지**:
  - A) `AddInstigator` 호출 유지 — InstigatorASC의 AvatarActor를 명시적으로 전달. 코드 의도는 명확하나 풀링 액터의 Instigator 미설정 문제를 외부에서 매번 해결해야 함.
  - B) `AddInstigator` 호출 제거 — `MakeEffectContext`가 세팅한 Instigator를 그대로 사용. 풀링 액터에서 `GetInstigator()`는 항상 null이므로 AddInstigator 자체가 불필요.

**결정**: B안. `MakeEffectContext()`는 `InstigatorASC` 기반으로 Instigator를 자동 세팅하므로 null `GetInstigator()`로 덮어쓰는 AddInstigator 호출이 오히려 유해.

**결과/효과**: GE 적용 즉시 데미지 정상 반영. PullVortexActor와 GroundEffectActor 동시 수정.

**포트폴리오 포인트**: GAS `EffectContext` 내부 구조 이해. `MakeEffectContext`의 암묵적 Instigator 세팅과 `AddInstigator`의 명시적 덮어쓰기 동작 구분. 무증상 실패(데미지 0)를 GAS 파이프라인 레이어별 로그로 추적한 진단 과정.

**관련 파일**: Source/.../GroundEffect/GroundEffectActor.cpp, PullVortexActor.cpp (ApplyGEToTarget)

**검증 기준**:
  - [x] PullVortexActor HitTick에서 에너미 HP 감소 확인
  - [x] GroundEffectActor Overlap 시 GE 정상 적용

---

### [2026-04-22] [BUG_FIX] HOMING_BOUNCE 투사체 — 다중 컴포넌트 OnBeginOverlap 중복 + HitType 우선순위 충돌

**UE_Ver**: 5.4
**Knowledge_Risk**: LOW

**상황**: 콩콩이(HOMING_BOUNCE) 투사체가 적 1기를 맞고 즉시 소멸. 로그에 Bounce 기록 없음. Lifetime 만료 메시지도 없음.

**문제/과제**: 두 개의 독립적 원인이 순서대로 발견됐다.

원인 1 — **HitType 우선순위 충돌**: `OnBeginOverlap`에서 `HitType == PIERCE` 체크가 `MoveType == HOMING_BOUNCE` 체크보다 먼저 실행된다. DT에 `HitType=PIERCE`가 설정되어 있어 `HandlePierceHit`이 호출됨. `PierceCount=1` → 첫 타격 후 `ReturnToPool`.

원인 2 — **다중 컴포넌트 중복 Overlap**: `IgnoreActorWhenMoving`은 이후 이동 sweep만 차단하고, 동일 프레임에 이미 발생한 이벤트를 막지 못한다. 에너미의 캡슐 + 스켈레탈 메시 컴포넌트가 모두 Pawn 채널에 응답하면 `HandleBounceHit`이 같은 Actor에 대해 2~3회 연속 호출 → `BounceHitCount`가 `MAX_BOUNCE_COUNT(3)`에 조기 도달 → 즉시 소멸.

**검토한 선택지 (원인 2)**:
  - A) `PiercedActors` 방식(TSet) — 별도 컨테이너 유지. 함수 진입 시 포함 여부 체크. 기존 Pierce 패턴 재사용.
  - B) `GetMoveIgnoreActors().Contains()` 조기 리턴 — 첫 호출에서 IgnoreActorWhenMoving 등록 직후, 두 번째 호출에서 맨 위 조기 리턴. 추가 컨테이너 불필요.

**결정**: B안. 이미 IgnoreActorWhenMoving 인프라가 있으므로 같은 목록을 중복 방어에 재활용. 코드가 단순하고 의도가 자명함.

**결과/효과**: HitType=SINGLE 수정 후 바운스 동작. 중복 방어 추가 후 3회 바운스 정상 작동.

**포트폴리오 포인트**: UE5 물리 이벤트 시스템의 컴포넌트 단위 발화 이해. `IgnoreActorWhenMoving`의 sweep-only 한계 파악. 진단 로그를 최소 삽입(`MoveType/HitType/Lifetime`)으로 원인 계층을 분리한 접근.

**관련 파일**: Source/.../Projectile/BaseProjectile.cpp (HandleBounceHit, OnBeginOverlap)

**검증 기준**:
  - [x] 적 1기 상대로 3회 바운스 후 소멸
  - [x] 다수 적 상대로 적당 1회씩 피해 적용

---

### [2026-04-22] [ARCH] HOMING_BOUNCE 다음 타겟 선택 전략 — 클러스터 스킵 + Z 튕김

**UE_Ver**: 5.4
**Knowledge_Risk**: LOW

**상황**: 바운스 투사체가 최근접 적을 다음 타겟으로 선택하도록 구현했으나, PullVortex 등 흡입 스킬로 적이 밀집한 상황에서 바운스가 관통(Pierce)과 구별이 안 됨. 또한 Z축 움직임이 없어 시각적으로 평면적.

**문제/과제**: 밀집 클러스터 내 최근접 선택은 방향 전환이 거의 없어 "튕기는" 연출을 살릴 수 없음.

**검토한 선택지**:
  - A) 최소 각도 임계값 필터 — 진행 방향 대비 N도 미만 후보 제외. 각도 계산으로 방향 전환 강제. 그러나 클러스터가 밀집하면 각도 조건 만족 후보가 여전히 클러스터 내에 존재.
  - B) 반사 벡터 기반 — 입사 방향을 반사해 가장 가까운 방향의 적 선택. 물리 바운스와 동일하나 반사 방향에 적이 없으면 실패율 높음.
  - C) 최소 거리 배제 + 폴백 — 현재 위치에서 `MinBounceSkipRadius` 이내 후보 전부 제외. 클러스터 전체를 공간적으로 스킵. 폴백으로 조건 미충족 시 최근접 복귀.

**결정**: C안. A/B는 클러스터 밀집 시 클러스터 내부 후보를 걸러내지 못하는 공통 한계가 있음. C는 공간 자체를 배제해 클러스터 통째를 스킵. `MinBounceSkipRadius` 단일 파라미터 노출로 튜닝 단순화.
Z 튕김: 타겟 재설정 시 현재 XY 속도에 `BounceZLaunchFactor` 비율로 Z 속도 추가 → homing 가속도가 타겟으로 당기는 동안 자연스러운 포물선 형성.

**결과/효과**: 적 밀집 환경에서 투사체가 클러스터를 건너뛰며 원거리 적으로 이동. Z 튕김으로 "통통이" 시각 연출 구현.

**포트폴리오 포인트**: 게임플레이 느낌(game feel) 문제를 기하학적 선택 전략으로 해결. 단순 거리 기반에서 공간 배제 + 폴백 구조로 확장하는 설계 결정.

**관련 파일**: Source/.../Projectile/BaseProjectile.h (MinBounceSkipRadius, BounceZLaunchFactor), BaseProjectile.cpp (HandleBounceHit)

**검증 기준**:
  - [x] 밀집 적 환경에서 바운스 시 클러스터 외부 적으로 이동
  - [x] 바운스 시 Z축 상승 후 타겟으로 곡선 유도

---

### [2026-04-21] [PATTERN] PostProcess 아웃라인 — CustomDepth 깊이차 비교 vs CustomStencil 이진 마스크

**UE_Ver**: 5.4
**Knowledge_Risk**: LOW

**상황**: 로비 캐릭터 선택 호버 시 외곽선을 표시하기 위해 PostProcess 머티리얼에서 `SceneTexture: CustomDepth`를 사용해 인접 픽셀 간 깊이 차이로 엣지를 감지하는 방식을 구현했다.

**문제/과제**: 캐릭터 메시에 커서를 올리면 외곽선만 빛나야 하는데 **메시 전체가 빛나는 현상** 발생. 원인 파악이 필요했다.

**검토한 선택지**:
- A) `CustomDepth` 깊이차 비교 (기존 구현)
  ```hlsl
  float edge = step(0.01, abs(Center - Right)) + ...;
  ```
  문제: CustomDepth는 카메라로부터의 월드 거리(실수)를 저장. 메시 **내부**에서도 인접 픽셀 간 깊이가 다르기 때문에(예: 팔 200, 몸통 205 units) `abs diff > 0.01` 조건이 내부 전체에서 참이 됨 → 메시 전체 발광.

- B) `CustomStencil` 이진 마스크 비교
  ```hlsl
  float IsCenter = step(0.5, Center); // 1=메시, 0=배경
  float edge = IsCenter * saturate((1-IsRight) + (1-IsLeft) + (1-IsDown) + (1-IsUp));
  ```
  C++에서 `SetCustomDepthStencilValue(1)` 호출. Stencil은 "메시 있음(1) / 없음(0)" 이진값이므로 내부 깊이 변화에 영향받지 않음.

**결정**: B안 채택. SceneTexture 노드 5개를 `CustomDepth` → `CustomStencil`로 교체하고 HLSL을 이진 비교로 변경.

**결과/효과**: 메시 외곽선만 정확하게 발광. 내부는 발광 없음.

**포트폴리오 포인트**: UE5 PostProcess 머티리얼에서 커스텀 깊이 버퍼의 두 채널(Depth: 실수 깊이 / Stencil: 이진 마스크) 특성 차이 이해. 화면공간 엣지 감지 알고리즘 구현 경험.

**관련 파일**: Content/PostProcess/M_LobbyOutline (머티리얼 에셋), LobbyCharacterActor.cpp

**검증 기준**:
  - [x] 커서 호버 시 메시 외곽선만 발광, 내부는 발광 없음
  - [x] `SetRenderCustomDepth(false)` 시 아웃라인 완전 소멸

---

### [2026-04-20] [ARCH] CC 시스템 설계 — GE GrantedTags vs SetByCaller float 인코딩

**UE_Ver**: 5.4
**Knowledge_Risk**: LOW

**상황**: AoE 스킬에 넉다운 CC를 추가하면서 GE가 "어떤 CC를 적용할지"를 EnemyAttributeSet에 전달하는 방법이 필요했다.

**문제/과제**: GAS의 GE는 데미지 수치(SetByCaller)는 전달할 수 있지만, "넉다운이냐 스턴이냐"는 열거형 정보를 전달하는 공식 채널이 명확하지 않았다.

**검토한 선택지**:
  - A) SetByCaller float 인코딩 — CC 종류를 1.0(넉다운), 2.0(스턴) 등으로 인코딩. 구현이 단순하나 GE와 코드 간 암묵적 계약이 생기고 태그 기반 GAS 철학에 반함.
  - B) GE GrantedTags에 CC 태그 부여 → PostGameplayEffectExecute에서 `GetAllGrantedTags()`로 읽어 분기 — GAS 설계 원칙에 부합, GE BP에서 태그만 추가하면 새 CC 종류 확장 가능.

**결정**: B안 채택. `CC.Knockdown` / `CC.Stun` / `CC.Blind` 태그를 네이티브 태그로 등록하고 `GetAllGrantedTags()`로 읽어 분기. Instant GE에서 `GrantedTags`가 ASC에 유지되지 않는 문제는 `GetAllGrantedTags()`가 실행 시점 스펙에서 직접 읽으므로 무관.

**결과/효과**: GE BP에서 태그 하나 추가로 CC 종류 지정 가능. C++ 코드 수정 없이 GE 레벨에서 CC 조합 가능한 확장성 확보.

**포트폴리오 포인트**: GAS GrantedTags의 Instant vs HasDuration 동작 차이 이해. GE Context(HitResult ImpactPoint)를 통한 AoE Center 기반 넉백 방향 계산 패턴.

**관련 파일**: Source/RoastStaffGAS/Private/GAS/Attributes/EnemyAttributeSet.cpp, Source/RoastStaffGAS/Private/GAS/Abilities/GA_CharacterSkill.cpp

**검증 기준**:
  - [x] CC.Knockdown 태그 GE 적용 시 ApplyKnockdown 호출
  - [x] CC 태그 없는 GE 적용 시 ApplyHitReact 호출
  - [x] AoE Center 기준 넉백 방향 정확 (에너미가 Center에서 멀어지는 방향)

### [2026-04-21] [ARCH] SpawnPreview 공유 BP 상태 오염 — 스킬별 GA BP 분리 결정

**UE_Ver**: 5.4
**Knowledge_Risk**: LOW

**상황**: SpawnPreview ActivationType을 스킬 3(텔레포트)과 스킬 5(장판 소환) 양쪽에 사용하면서 `bTeleportOnConfirm` 플래그로 동작을 분기하려 했다. 스킬 5가 SpawnPreview 타입으로 변경되자 예상치 못하게 텔레포트 동작을 했다.

**문제/과제**: 원인 조사 결과, 공유 BP(`GA_CharacterSkill_SpawnPreview`)에 `FXActorClass`가 설정되어 있었고, 이전 코드에서 ExecuteSpawnPreview가 `FXActorClass` 존재 여부와 무관하게 항상 텔레포트를 수행하는 구조였음. `bTeleportOnConfirm` 플래그를 추가해도 `EditDefaultsOnly` 속성은 BP 클래스 단위로 공유되므로, 플래그를 true로 설정하면 해당 BP를 사용하는 **모든 스킬**이 텔레포트하게 됨.

**검토한 선택지**:
  - A) 공유 BP에 `bTeleportOnConfirm` 플래그 추가 후 분기 — 플래그 자체는 맞는 설계지만, BP가 공유되는 한 스킬별로 다른 값을 가질 수 없음. 결국 동작이 다른 스킬마다 별도 BP가 필요해 근본 해결이 아님.
  - B) 스킬별 GA BP 분리 (Painter03, Painter05 전용 BP) — EditDefaultsOnly 속성을 스킬별로 독립적으로 설정 가능. BP 수가 늘어나는 단점은 있으나, 이는 곧 GA/Actor 레이어 구조 재설계(PLAN_SkillSystemArch)로 해소 예정.

**결정**: B안. 스킬별 GA BP를 분리하고, 추후 `SkillGEClass`를 DataTable로 이동해 GA BP를 ActivationType 단위로만 유지하는 구조 리팩토링을 별도 PLAN으로 잡기로 결정.

**결과/효과**: Painter03(텔레포트, bTeleportOnConfirm=true), Painter05(장판, false)가 각각 독립 동작. 동시에 아키텍처 문제가 구체적으로 드러나 PLAN_SkillSystemArch_v1.0 착수 근거 확보.

**포트폴리오 포인트**: UE5 `EditDefaultsOnly`가 BP 클래스 인스턴스가 아닌 클래스 단위로 값을 공유함을 간과한 버그 케이스. "같은 타입이면 BP 공유 가능"이라는 가정이 깨질 때 발생하는 구조적 문제와, 이를 계기로 시스템 레이어 설계를 재검토한 의사결정 과정.

**관련 파일**:
  - Source/RoastStaffGAS/Public/GAS/Abilities/GA_CharacterSkill.h (bTeleportOnConfirm)
  - Source/RoastStaffGAS/Private/GAS/Abilities/GA_CharacterSkill.cpp (ExecuteSpawnPreview)
  - Content/GAS/GA/Character/Painter/ (GA BP 분리)

**검증 기준**:
  - [x] 스킬 3 발동 시 텔레포트, 스킬 5 발동 시 텔레포트 없이 장판 소환
  - [x] 소서리스/호크아이 SpawnPreview 스킬 텔레포트 없음

---

### [2026-04-18] [ARCH] 캐릭터 스킬 ProjectileSpawn — DataTable 신규 컬럼 vs SkillEffectID FK 재사용

**UE_Ver**: 5.4
**Knowledge_Risk**: LOW

**상황**: 캐릭터 고유 스킬(Q/E)에 ProjectileSpawn 타입을 추가하면서 투사체 파라미터(속도, 수명, 관통 수 등)를 어디에 저장할지 결정해야 했다.

**문제/과제**: `FCharacterSkillStaticData`에 ProjectileClass, Speed, PierceCount 등 파라미터를 직접 추가하는 초기 구현이 이미 존재하는 무기 스킬 테이블(DT_Skill_Attack_Common_Params_Data, DT_Skill_Attack_HitType_Params_Pierce 등)과 동일한 데이터를 중복 정의하는 구조가 됨. 같은 수치를 두 곳에서 관리하면 수정 시 불일치 발생 위험.

**검토한 선택지**:
  - A) `FCharacterSkillStaticData`에 직접 파라미터 추가 (초기 구현) — 구현이 단순하나 무기 스킬 테이블과 데이터 중복. 수치 변경 시 두 테이블 동기화 필요. 나중에 타입별 파라미터가 늘어날수록 구조체가 비대해짐.
  - B) `SkillEffectID` FK를 추가하고 GDS 복합 조회로 기존 테이블 재사용 — FK 하나만 추가하면 무기 스킬 인프라(AttackCommonParams, SpawnParams, HitTypePierce) 전체를 공유. 단, 캐릭터 스킬 SkillID로 DT_Skill_Common_Resource_Data에 row도 추가해야 한다는 에디터 설정 부담 존재.

**결정**: Option B 선택. DRY 원칙 우선 — 수치가 두 곳에 있으면 버그 재현이 어렵고 DataTable 유지보수 비용이 높아진다. 에디터 설정 부담은 개발 초기에 수용 가능한 수준.

**결과/효과**: `FCharacterSkillStaticData`에 `SkillEffectID`와 `FireInterval`(캐릭터 스킬 전용 burst 파라미터) 2개만 추가. `GetCharacterSkillExecData`가 SkillEffectID를 통해 기존 캐시 5개(Resource, AttackCommon, CommonParam, SpawnParams, HitTypePierce)를 복합 조회해 `FCharacterSkillExecData`를 완성. 하드코딩 10.f도 `AttackCommonParams.Amount`로 대체되어 제거.

**포트폴리오 포인트**: 데이터 중복 vs FK 재사용 트레이드오프 인식 / 기존 스키마를 최소 변경으로 확장하는 OCP 적용 / GDS 복합 조회 패턴 설계

**관련 파일**:
  - Source/RoastStaffGAS/Public/Data/DataTableStructs.h (FCharacterSkillStaticData)
  - Source/RoastStaffGAS/Public/Data/RuntimeDataStructs.h (FCharacterSkillExecData)
  - Source/RoastStaffGAS/Private/Subsystems/GameDataSubsystem.cpp (GetCharacterSkillExecData)

**검증 기준**:
  - [x] 빌드 성공 (2026-04-18)
  - [ ] ProjectileSpawn 타입 스킬 발동 시 DT row 설정대로 투사체 발사 확인

---

### [2026-04-14] [BUG_FIX] LoadingWidget Dangling Pointer — 레벨 전환 시 UIManagerSubsystem 캐시 불일치

**상황**: InGame 진입 후 LoadingWidget이 PreWarm 완료 전에 닫히고, 첫 무기 슬롯 등록이 지연되는 버그. `FinishLoading()` 호출 시점에 `IsVisible: 0` 로그 발견.

**문제/과제**: 레벨 전환(TransitionGameMode → RSGameMode) 시 Widget의 World가 파괴되면서 Widget 자체도 파괴됨. 그러나 GameInstanceSubsystem인 UIManagerSubsystem은 레벨 간 유지되어 `bIsOpen=true` + dangling pointer 상태 잔존. 새 World에서 `OpenUIByID` 호출 시 `bIsOpen=true` 조기 반환으로 `AddToViewport` 스킵 → Widget은 메모리에만 있고 Viewport에는 없는 상태.

**검토한 선택지**:
  - A) LOADING UI를 PAGE → SYSTEM 레이어로 변경 — 레이어 변경으로는 World 파괴 문제 미해결
  - B) RSGameMode::BeginPlay에서 LoadingWidget 강제 재생성 — 레벨마다 새 Widget 생성, 깜빡임 우려
  - C) dangling 상태 감지 후 CloseUI → OpenUI — `IsOpen() && !IsInViewport()` 조건으로 정확히 식별

**결정**: C 선택. `BeginPlay`에서 `GetWidgetByID` 조회 후 dangling 상태 확인, `CloseUIByID`로 `bIsOpen` 플래그 리셋 후 `OpenUIByID` 재호출로 `AddToViewport` 보장.

**결과**: LoadingWidget이 RSGameMode BeginPlay 시점에 정상적으로 Viewport에 추가되고, PreWarm 진행률 갱신 및 FinishLoading 정상 동작 확인. 레벨 전환 간 UI 상태 불일치 해소.

**포트폴리오 포인트**: UMG Widget의 World 소유권과 GameInstanceSubsystem의 생명주기 차이 이해 / Widget이 파괴된 후 캐시만 남은 dangling 상태를 `IsInViewport()` 조건으로 식별하는 방어적 초기화 패턴 적용

**관련 파일**: `Source/RoastStaffGAS/Private/Core/RSGameMode.cpp:54-61`, `Source/RoastStaffGAS/Private/UI/Transition/RSLoadingWidget.cpp`

---

### [2026-04-14] [ARCH] 레벨업 카드 선택 로직 — Widget 직접 처리 vs LevelUpSubsystem 위임

**상황**: MODULE-6에서 레벨업 카드를 무기 전용에서 스탯/패시브/무기 혼합으로 확장. 기존에는 Widget이 카드 선택 시 `EquipSys->EquipWeapon()`을 직접 호출하는 구조.

**문제/과제**: 카드 타입이 4종(StatUpgrade / PassiveAdd / WeaponUpgrade / WeaponNew)으로 늘어나면서 각 타입마다 다른 서브시스템을 호출해야 함. Widget이 이 분기를 직접 처리하면 Widget이 게임 로직을 알아야 하는 구조가 됨.

**검토한 선택지**:
  - A) Widget에서 CardType 분기 후 각 서브시스템 직접 호출 — 간단하지만 Widget이 EquipSys/PassiveSys/ASC를 알아야 함. 카드 타입 추가 시 Widget 수정 필요
  - B) Widget은 CardID만 전달, LevelUpSubsystem이 타입 조회 후 처리 — Widget은 "무엇인지 모르고 ID만 던짐". 카드 타입 추가 시 Subsystem만 수정

**결정**: B 선택. `LevelUpSubsystem::OnCardSelected(CardID)`가 GDS 조회로 타입 판별 후 StatUpgrade→ASC 직접 적용 / PassiveAdd→PassiveSlotSubsystem / 무기→EquipmentSubsystem으로 분기.

**결과**: Widget이 게임 로직 의존성 제로. 카드 타입 추가 시 LevelUpSubsystem만 수정. TDA(Tell Don't Ask) 원칙 적용 — Widget이 상태를 물어보지 않고 서브시스템에게 위임.

**포트폴리오 포인트**: UI-Logic 역할 분리 / TDA 원칙 적용으로 확장성 확보 / 단일 책임 원칙

**관련 파일**: `Source/RoastStaffGAS/Private/Subsystems/LevelUpSubsystem.cpp:385`, `Source/RoastStaffGAS/Private/UI/LevelUpWeaponSelectWidget.cpp:144`

---

### [2026-04-14] [PATTERN] GameInstanceSubsystem에서 WorldSubsystem 접근

**상황**: `ULevelUpSubsystem`(GameInstanceSubsystem)이 `UPassiveSlotSubsystem`(WorldSubsystem)에 접근해야 함.

**문제/과제**: `UGameInstanceSubsystem`은 `UObject` 기반 → `GetWorld()` 직접 호출 불가한 것처럼 보임. `GetGameInstance()->GetWorld()->GetSubsystem<>()` 수동 작성.

**검토한 선택지**:
  - A) `GetGameInstance()->GetWorld()->GetSubsystem<>()` 수동 — 장황, null 체크 필요
  - B) `GET_WORLD_SUBSYSTEM` 매크로 — 프로젝트 표준이나 GameInstanceSubsystem에서 동작 여부 불확실

**결정**: B 확인 후 적용. `UGameInstanceSubsystem::GetWorld()`가 내부적으로 `GetGameInstance()->GetWorld()`를 반환하도록 오버라이드되어 있어 매크로가 정상 동작.

**결과**: 프로젝트 전체 매크로 일관성 유지. linter가 수동 코드를 매크로로 자동 교체.

**포트폴리오 포인트**: UE5 서브시스템 생명주기 이해 / GameInstance ↔ World 계층 구조 파악

**관련 파일**: `Source/RoastStaffGAS/Private/Subsystems/LevelUpSubsystem.cpp:177`

---

### [2026-04-14] [BUG_FIX] AutoFire 즉시 발사 — PreWarm 중 타이머 등록 + SetTimer 초기 딜레이 0초 문제

**상황**: PreWarm 완료 직후 보스가 스폰되자마자 무기 스킬이 즉시 발사되고 EndAbility 로그가 찍히는 버그. UI에는 슬롯이 표시되기 전에 스킬이 이미 소진됨.

**문제/과제**:
1. `EquipmentSubsystem::CommitSlot`에서 `StartAutoFire` 즉시 호출 → PreWarm 중에도 타이머 등록됨 → 적이 없어 타겟 없이 발사 스킵
2. `SetTimer`의 초기 딜레이 파라미터가 `0.f`로 설정되어 타이머 등록 즉시 첫 발사 실행

**검토한 선택지**:
  - A) StartAutoFire를 private→public으로 이동, StartStageFlow에서 재호출 — API 노출 증가, 복잡도 상승
  - B) `ARSGameMode::bIsPreWarmActive` public 플래그 추가, StartAutoFire에서 조기 리턴 — 단순 명확
  - C) SetTimer 초기 딜레이를 Cooldown 값으로 변경 — 첫 발사가 Cooldown만큼 지연(8초 무기는 8초 대기)

**결정**: B + 고정 딜레이 상수.
  - B안 채택: `bIsPreWarmActive` 체크로 PreWarm 중 타이머 등록 스킵
  - 초기 딜레이: `AUTO_FIRE_START_DELAY = 5.f` 상수 추가, Cooldown과 무관하게 고정 5초 후 첫 발사

**결과**: PreWarm 중에는 타이머 미등록, 완료 후 첫 무기 장착 시 타이머 등록, 5초 후 첫 발사. 보스 스폰(~1초) + 고정 딜레이(5초) = 총 6초 후 자동 공격 시작으로 자연스러운 전투 시작 타이밍 확보.

**포트폴리오 포인트**: SetTimer의 초기 딜레이 파라미터 활용 / GameMode 상태 플래그를 통한 Subsystem 간 동기화 / 사용자 피드백("노. 아니야 이 방식은 잘못됐어")을 받아 즉시 롤백하고 더 단순한 해법 채택한 협업 사례

**관련 파일**: `Source/RoastStaffGAS/Public/Subsystems/EquipmentSubsystem.h:95`, `Private/Subsystems/EquipmentSubsystem.cpp:292-309`, `Public/Core/RSGameMode.h:77`

---

### [2026-04-13] [ARCH] SpawnPreview 액터 — GameMode 전역 단일 클래스 → DT 스킬별 분리

**상황**: SpawnPreview 타입 캐릭터 스킬이 구현됐지만, 모든 캐릭터의 프리뷰가 동일한 액터(GameMode.PreviewActorClass)를 사용. 캐릭터마다 다른 형태의 프리뷰(범위 표시, 투사체 방향 표시 등)가 필요함
**문제**: GameMode에 단일 `TSubclassOf<ASummonPreviewObject> PreviewActorClass` UPROPERTY를 두고 SkillManagerSubsystem이 이를 참조하는 구조. 스킬이 늘어날수록 분기 처리가 GameMode에 누적되는 구조적 결함
**검토한 선택지**:
  - A) `DT_CharacterSkill`에 `PreviewActorClass (TSoftClassPtr<ASummonPreviewObject>)` 추가 — 완전 데이터 드리븐, GameMode 의존성 0
  - B) `GA_CharacterSkill` 서브클래스화 — 캐릭터마다 BP_GA 별도 제작. 에디터 파일 증가, 스킬 추가 시 비용 큼
**결정**: A 선택. `CSV→DataTable→Subsystem→GA` 원칙에 완벽히 부합. GameMode의 `PreviewActorClass` UPROPERTY·getter 제거. `PreviewFXClass(TSoftClassPtr<UNiagaraSystem>)` 도 제거 — PreviewActor BP가 자체 FX 컴포넌트를 보유하므로 중복
**결과**: SkillManagerSubsystem이 `ExecData.PreviewActorClass.LoadSynchronous()`로 스킬별 액터 스폰. 미설정 시 `ASummonPreviewObject::StaticClass()` 폴백
**포트폴리오 포인트**: 데이터 드리븐 아키텍처 원칙을 지키기 위해 GameMode 전역 상태를 DT 행 단위로 분해한 설계 판단
**관련 파일**: `DataTableStructs.h:695`, `SkillManagerSubsystem.cpp:192-220`, `RSGameMode.h`

---

### [2026-04-13] [ARCH] GA_CharacterSkill FX 스폰 — Niagara Radius 파라미터 주입

**상황**: InstantAoE·SelfBuff·SpawnPreview 모두 GE 적용(데미지/버프)만 하고 시각 피드백이 없었음. `FCharacterSkillLevelData.FXClass`는 정의돼 있었으나 GA에서 미사용
**문제**: `FXClass`가 `TSoftClassPtr<UNiagaraSystem>`으로 선언돼 있어 에디터 피커에서 에셋이 표시되지 않는 타입 오류
**결정**: `TSoftObjectPtr<UNiagaraSystem>`으로 수정(에셋 참조). `SpawnSkillFX(FXClass, Location, Radius)` 헬퍼로 공통화. Niagara 컴포넌트에 `SetVariableFloat("Radius", Radius)` 주입으로 이펙트 크기를 데이터로 제어
**결과**: AoE·SelfBuff → 캐릭터 위치, SpawnPreview → 확정 위치에 FX 스폰. Niagara 시스템 내부에서 Radius User Parameter를 읽어 이펙트 범위 설정
**포트폴리오 포인트**: TSoftClassPtr/TSoftObjectPtr 구분(클래스 vs 에셋), Niagara User Parameter 런타임 주입 패턴
**관련 파일**: `GA_CharacterSkill.cpp:195-215`, `DataTableStructs.h:664`

---

### [2026-04-13] [BUG_FIX] EquipmentSubsystem 재진입 시 무기 슬롯 미등록

**상황**: GameInstanceSubsystem은 레벨 전환에도 유지됨. InGame → Lobby → InGame 재진입 시 시작 무기가 Slot에 등록되지 않음
**문제**: `DeinitializeSubsystem()`이 `ASC`, `bIsInitialized`만 리셋하고 `Slots[]` 배열은 초기화 안 함 → 재진입 시 이전 세션의 WeaponID 잔존 → `IsEmpty()=false` → `GetEmptySlotIndex()=INDEX_NONE` → `OnSlotFull` 오발동
**검토한 선택지**:
  - A) `DeinitializeSubsystem`에서 Slots[] 초기화 — 해제 시점에 처리
  - B) `InitializeSubsystem`에서 Slots[] 완전 초기화 후 SlotIndex 재설정 — 진입 시점에 방어
**결정**: B 선택. 초기화 시점 방어가 더 명확한 진입점 보장. `Slots[i] = FWeaponSlotInstanceData()` 후 `Slots[i].SlotIndex = i`
**결과**: 재진입 시 슬롯 정상 등록 확인
**포트폴리오 포인트**: GameInstanceSubsystem 생명주기와 레벨 전환 간 상태 잔존 문제 식별 및 방어적 초기화 적용
**관련 파일**: `Source/.../EquipmentSubsystem.cpp:30-34`

---

### [2026-04-13] [BUG_FIX] SpawnPreview EffectRadius=0 → 반경 1cm 오버랩으로 데미지 미적용

**상황**: CHAR_ROGUE/MAGE의 SpawnPreview 스킬이 첫 확정 시는 데미지가 들어가나 이후 전혀 안 됨
**문제**: DT_CharacterSkill의 SpawnPreview 행에 `EffectRadius=0` 입력. `ExecuteSpawnPreview`에서 `FMath::Max(1.f, 0.f)` → 반경 1cm 구체로 오버랩 → 적 미탐지. 첫 번째 동작한 이유는 플레이어가 적에 매우 근접한 경우였음
**진단 과정**: TryActivateAbility 결과 로그 + OnAbilityActivated 진입 로그 추가 → GA는 정상 진입 → OverlapMultiByChannel 반환값 0 확인 → Radius 추적 → EffectRadius=0 발견
**결정**: DT에서 SpawnPreview 행에 EffectRadius 값 직접 입력하여 해결 (C++ 변경 없음)
**교훈**: `FMath::Max(1.f, x)` 패턴은 0 입력 시 사실상 "무반응"으로 침묵하는 버그. DT 필드가 실제 코드에서 어떻게 쓰이는지 설명 전 코드 확인 필수
**포트폴리오 포인트**: GAS 능력 활성화 단계별 로그를 직접 삽입해 레이어별로 좁혀가는 디버깅 방법론 적용
**관련 파일**: `Source/.../GA_CharacterSkill.cpp:136`, `ExternalSource/DT_Character_Skill_Static_Data.csv`

---

### [2026-04-13] [BUG_FIX] 스테이지 클리어 후 캐릭터 해금 미처리

**상황**: STG_003 클리어 후 CHAR_MAGE가 캐릭터 선택 화면에서 잠금 해제되지 않음
**문제**: `RSGameMode::SaveResult` → `SGS->UpdateStageRecord()` 내부에서 `ClearedStageIDs` 갱신은 되나, `SGS->UnlockCharacter()` 호출 경로가 코드 어디에도 없음. DT에 `UnlockType=STAGE_CLEAR`, `UnlockStageID=STG_003` 데이터가 올바르게 있었음에도 미연결
**결정**: `SaveResult`에서 `bCleared=true` 시 `GDS->GetAllCharacterStaticData()`로 전체 캐릭터 조회 → `UnlockType==STAGE_CLEAR && UnlockStageID==CurrentStageID` 조건 캐릭터에 `SGS->UnlockCharacter()` 호출. `UpdateStageRecord` 전에 처리해 해금 데이터가 동일 `SaveGame()` 호출에 포함되도록
**결과**: 클리어 시 해당 캐릭터 즉시 해금 및 디스크 저장 확인
**포트폴리오 포인트**: 데이터 저장과 파생 상태 갱신의 원자성 — 해금 처리를 UpdateStageRecord(SaveGame 포함) 이전에 배치해 단일 저장 호출로 묶음
**관련 파일**: `Source/.../RSGameMode.cpp:364-390`, `Source/.../SaveGameSubsystem.cpp:134`

---

### [2026-04-09] [ARCH] StageSelectWidget 복원 — 저장 시점 선택과 기존 함수 재사용

**상황**: 로비 복귀 시 스테이지 선택 화면이 항상 초기화 상태로 시작 — 재도전 UX 단절.

**문제·과제**: LastPlayedStageID를 언제 저장할지, 복원 시 UpdateDetailPanel / SelectedStageID / Btn_Confirm 3개 상태를 중복 없이 정확히 복원하는 방법.

**검토한 선택지**:
- 저장 시점: OnStageSelected(진입 확정) vs UpdateStageRecord(스테이지 종료) — UpdateStageRecord는 실패 케이스도 포함하므로 "마지막 진입 스테이지" 의미와 불일치
- 복원 방법: OnNodeClicked 재사용 vs 3개 상태 직접 조작 — 직접 조작 시 OnNodeClicked 내부 변경에 취약 (LOCKED 방어 로직 누락 위험)

**결정**: 저장은 OnStageSelected에서 SaveGame() 직전 일괄 (세이브 기획서 트리거 정책 준수). 복원은 OnNodeClicked 재사용 — LOCKED 방어 자동 처리 + DRY 보장. PopulateNodeMap() 이후 순서 고정으로 NodeDataCache 선행 조건 보장.

**결과**: 6개 파일 수정, 신규 파일 없음. 재도전 UX 복원 완료.

**포트폴리오 포인트**: 기존 함수 재사용으로 3개 상태 동기화 문제를 없앤 판단 + 저장 시점의 의미 정합 고려 (진입 확정 vs 종료 결과).

**관련 파일**: RSGameSave.h, SaveGameSubsystem.h/.cpp, RSOutGamePlayerController.cpp, RSStageSelectWidget.h/.cpp

---

### [2026-04-08] [ARCH] Private 헬퍼 배치 — anonymous namespace vs private member

**상황**: PoolingSubsystem과 RSGameMode 리팩토링 중 `.cpp`에서만 사용되는 헬퍼 함수(`PopFirstValid<T>`, `SpawnOnePreWarmUnit`, `CollectUniqueEnemyClasses` 등)의 배치 위치를 결정해야 했다.

**문제/과제**: `anonymous namespace`에 두면 헤더 노출 없이 완전 은닉 가능하나, UE 리플렉션/UFUNCTION 매크로와 함께 사용 불가. `private member`로 두면 헤더에 선언이 필요하다.

**검토한 선택지**:
  - A) `anonymous namespace` — 완전 은닉, 외부 노출 없음. 그러나 UFUNCTION 불가, this 포인터 접근 시 매개변수 전달 필요
  - B) `private member` — 헤더 노출, 클래스 인터페이스 오염. 단 UFUNCTION 가능, this 자연 참조

**결정**: B 선택. UE 코드베이스에서 헬퍼 함수는 `private member`가 표준이며, `anonymous namespace`는 순수 static 유틸리티(UObject 무관)에만 허용. conventions.md에 원칙 추가.

**결과/효과**: 모든 private 헬퍼에 헤더 선언 확보. 팀 규칙으로 정착.

**포트폴리오 포인트**: UE 코드 구조 관례 이해 / C++ 은닉 메커니즘 선택 근거 설명 능력

**관련 파일**: `Source/RoastStaffGAS/Public/Subsystems/PoolingSubsystem.h`, `.claude/skills/coding/references/conventions.md`

---

### [2026-04-08] [REFACTOR] PopFirstValid<T> 템플릿 — Actor/Widget Pool Pop 루프 중복 제거

**상황**: `SpawnPooledActor`, `SpawnPooledWidget` 각각의 Pop 루프가 동일한 구조(IsValid 체크 → 유효하지 않은 객체 건너뛰기)를 중복 구현하고 있었다.

**문제/과제**: 같은 로직이 Actor/Widget 두 경로에 복사되어 있어, Pop 정책 변경 시 2곳을 동기화해야 함.

**검토한 선택지**:
  - A) 현행 유지 — 구현 단순, Pop 정책 변경 시 두 곳 수정 필요
  - B) `PopFirstValid<T>(TArray<T*>&)` 템플릿 함수 추출 — 단일 정의, Actor/Widget 모두 재사용

**결정**: B 선택. IsValid가 UObject 계층에서 공통으로 동작하므로 템플릿화 가능. 함수 시그니처: `template<typename T> T* PopFirstValid(TArray<T*>& Pool)`.

**결과/효과**: Pop 루프 중복 제거. Pop 정책 변경 시 단일 지점만 수정.

**포트폴리오 포인트**: UE에서 UObject 계층 공통성을 활용한 템플릿 설계 / 중복 제거와 YAGNI 균형

**관련 파일**: `Source/RoastStaffGAS/Public/Subsystems/PoolingSubsystem.h`, `Private/Subsystems/PoolingSubsystem.cpp`

---

### [2026-04-08] [BUG_FIX] constexpr 타입 절삭 — int32에 float 리터럴 대입

**상황**: SR-FULL(2026-04-08)에서 발견. `GA_ProjectileAttack.cpp`의 발사 각도 클램프 상수 `constexpr int32 LAUNCH_ANGLE_CLAMP = 80.f`.

**문제/과제**: `int32` 타입에 `80.f` float 리터럴 대입 → 묵시적 절삭(truncation) 발생. 현재는 80이라 값 손실 없지만 컴파일러 경고(C4244) 대상이고, 향후 소수점 값으로 바뀔 경우 실제 손실.

**검토한 선택지**:
  - A) `constexpr float LAUNCH_ANGLE_CLAMP = 80.f` — 사용처(`FMath::Clamp<float>`)와 타입 일치
  - B) `constexpr int32 LAUNCH_ANGLE_CLAMP = 80` — 정수 리터럴로 통일

**결정**: A 선택. 클램프 대상이 float 연산이므로 float 타입이 자연스럽다.

**결과/효과**: 타입 불일치로 인한 암묵적 변환 제거. "constexpr 선언 시 사용처 타입에 맞춰 선언" 규칙으로 내면화.

**포트폴리오 포인트**: C++ 타입 시스템과 컴파일러 경고 주의 / constexpr 선언 시 타입 정합성 점검 습관

**관련 파일**: `Source/RoastStaffGAS/Private/GAS/Abilities/GA_ProjectileAttack.cpp`

---

### [2026-04-08] [ARCH] Enemy 계층 투사체 발사 중복 — Template Method 추출 계획

**상황**: SR-FULL(2026-04-08)에서 신규 발견. `ARangedEnemy::FireProjectile`, `AEliteEnemy::FireProjectile`, `ABossEnemy::LaunchProjectileInDirection`이 동일한 3단계(풀 획득 → InitEnemyProjectile → 방향 계산)를 반복 구현. 클래스별 float 파라미터(`PreferredRange`, `MaxAttackRange`, `ProjectileSpeed`, `ProjectileLifetime`, `AttackDamage`)도 3개 클래스에 15개 중복 선언.

**문제/과제**: 투사체 발사 정책 변경 시 3곳 동시 수정 필요. 파라미터 필드도 15개가 UPROPERTY 없는 plain float로 중복.

**검토한 선택지**:
  - A) 현행 유지 — 클래스 독립성 높으나 변경 비용 3배
  - B) `EnemyBaseCharacter`에 `LaunchEnemyProjectile(Direction, Damage, GEClass)` 공통 헬퍼 추출 + 파라미터를 `FEnemyRangedParams` USTRUCT로 통합

**결정**: B 예정 (다음 스프린트). 공통 헬퍼는 Template Method 패턴, 파라미터 구조체는 DataTable 외부화와 자연스럽게 연결.

**결과/효과**: (구현 예정) 발사 정책 단일 지점 수정. Enemy 종류 추가 시 파라미터 재선언 불필요.

**포트폴리오 포인트**: 계층 구조에서 반복 패턴 식별 능력 / Template Method + USTRUCT 조합 설계

**관련 파일**: `Source/RoastStaffGAS/Public/Character/Enemy/EnemyBaseCharacter.h` (예정), `RangedEnemy.h`, `EliteEnemy.h`, `BossEnemy.h`

---

### [2026-04-07] [PATTERN] Instigator 패턴 — 투사체 자기 충돌 방지

**상황**: 에너미가 발사한 투사체가 발사 직후 자기 자신과 충돌하는 버그. 초기 접근은 발사 오프셋 하드코딩(`SPAWN_OFFSET = 200.f`)이었다.

**문제/과제**: 오프셋 방식은 캡슐 크기·충돌 채널 변경에 취약하고, 오프셋 값 자체가 또 다른 하드코딩.

**검토한 선택지**:
  - A) 발사 오프셋 하드코딩 — 즉각 적용 가능, 물리 레이어 변경에 취약
  - B) Instigator 패턴 — `Projectile->SetInstigator(OwnerEnemy)` + `SphereComp->IgnoreActorWhenMoving(GetInstigator())` 조합

**결정**: B 선택. 의미 기반 무시 — "발사자를 무시한다"는 의도가 코드에 직접 표현됨. 물리 설정 변경에 독립적.

**결과/효과**: 오프셋 없이 자기 충돌 방지. Elite/Boss 투사체에도 동일 패턴 재사용.

**포트폴리오 포인트**: 하드코딩 vs 의미 기반 솔루션 선택 / UE Instigator API 실전 활용

**관련 파일**: `Source/RoastStaffGAS/Private/Character/Enemy/EnemyProjectile.cpp`

---

### [2026-04-07] [PATTERN] UE_LOG Verbose 필터링 — 진단 로그가 안 보이는 함정

**상황**: 디버깅 중 `KHS_DEBUG` 카테고리로 `Verbose` 레벨 로그를 출력했는데, Output Log에 아무것도 표시되지 않아 "버그 없음"으로 오판할 뻔했다.

**문제/과제**: UE5 Output Log의 기본 필터는 `Display` 이상이라 `Verbose`, `VeryVerbose`는 기본 상태에서 표시되지 않는다. 에러나 경고 없이 조용히 숨겨진다.

**근본 원인**: `UE_LOG(KHS_DEBUG, Verbose, ...)` → Output Log 기본 필터에서 숨김. 에디터 필터를 명시적으로 낮추거나 카테고리 로그 레벨을 올려야 표시됨.

**결정**: 진단 중 로그는 `KHS_INFO`(`Display` 레벨) 이상 사용. `Verbose`는 배포 시 억제 목적이므로 진단 단계에서 부적합.

**결과/효과**: "로그 없음 = 정상 동작" 오독 함정 제거. UE_LOG 6단계(Fatal/Error/Warning/Display/Verbose/VeryVerbose)와 Output Log 필터 기준 내면화.

**포트폴리오 포인트**: UE 로깅 시스템 깊이 이해 / 진단 도구를 올바르게 사용하는 습관

**관련 파일**: `Source/RoastStaffGAS/Public/Core/Logging/RSLoggingSystem.h`

---

### [2026-04-08] [ARCH] PoolingSubsystem AsyncPreWarm — UTickableWorldSubsystem 기반 배치 스폰

**상황**: 인트로 로딩 중 Enemy Actor와 Widget을 미리 스폰해 Pool에 적재해야 했다.
이전 구조는 EnemySpawner가 직접 InitializePool을 호출하는 방식으로, 호출 위치가 분산되어 있었다.

**문제/과제**: 스테이지 시작 전 수십 개의 Actor를 한 프레임에 스폰하면 프레임 스파이크 발생.
로딩 UI와 연동하는 완료 이벤트도 필요했다.

**검토한 선택지**:
  - A) BeginPlay 일괄 스폰 — 구현 단순, 그러나 한 프레임에 집중되는 스폰 비용으로 히칭 발생
  - B) Tick 분산 배치 스폰 (UTickableWorldSubsystem 변환) — 프레임당 N개 제한, 외부 튜닝 가능
  - C) AsyncTask 오프로드 — Actor 스폰이 GameThread 의존이라 실질적으로 불가

**결정**: B 선택.
`UTickableWorldSubsystem`으로 변경해 매 Tick에 `PreWarmBatchSize`개씩 스폰.
`GetPreWarmProgress()` float 반환으로 로딩 바 연동, `OnPreWarmComplete` FSimpleMulticastDelegate로 완료 이벤트 노출.

**결과/효과**: 스폰 비용이 여러 프레임으로 분산. 완료 델리게이트를 통해 GameMode가 PreWarm 종료 후 스테이지 진입 로직을 구동.

**포트폴리오 포인트**: UTickableWorldSubsystem 활용한 프레임 예산 분산 패턴 / 델리게이트 기반 비동기 완료 통지 설계

**관련 파일**: `Source/RoastStaffGAS/Public/Subsystems/PoolingSubsystem.h`, `Private/Subsystems/PoolingSubsystem.cpp`

---

### [2026-04-08] [BUG_FIX] ActorPool GC 크래시 — TArray<AActor*> UPROPERTY 누락

**상황**: `PoolingSubsystem`이 스폰한 Actor를 TArray에 보관하고 있었는데,
특정 조건(장시간 플레이, GC 수행 타이밍)에서 풀에서 꺼낸 Actor가 이미 소멸된 상태로 반환됐다.

**문제/과제**: TArray<AActor*>는 UPROPERTY가 없으면 UE GC의 추적 대상에서 제외된다.
GC 사이클에서 "참조 없음"으로 판단해 Actor를 수집(collect)해버림.

**검토한 선택지**:
  - A) TArray에 UPROPERTY 추가 — 가장 단순, 하지만 USTRUCT 내부 TArray는 UPROPERTY 불가
  - B) TArray를 USTRUCT(`FActorPoolBucket`)로 래핑 후 UPROPERTY 선언 — GC 추적 보장
  - C) TWeakObjectPtr 사용 — 약참조라 스폰된 Actor를 GC로부터 보호 불가

**결정**: B 선택. `FActorPoolBucket` USTRUCT를 도입해 `TArray<AActor*> Actors`를 감싸고,
`TMap<TSubclassOf<AActor>, FActorPoolBucket>`에서 UPROPERTY로 선언.

**결과/효과**: GC가 FActorPoolBucket 내부 Actors를 추적하게 되어 크래시 재현 불가.
`FWidgetPoolBucket`도 동일 패턴으로 구현해 Widget 풀에도 적용.

**포트폴리오 포인트**: UE GC 추적 메커니즘 이해 / USTRUCT 래퍼를 통한 UPROPERTY 강참조 확보 패턴

**관련 파일**: `Source/RoastStaffGAS/Public/Subsystems/PoolingSubsystem.h` (`FActorPoolBucket`, `FWidgetPoolBucket`)

---

### [2026-03] [PATTERN] UMG AddDynamic 바인딩 위치 — NativeOnInitialized vs NativeConstruct

**상황**: Widget을 Pool에서 꺼내 재사용할 때 델리게이트가 중복 바인딩되는 버그를 발견했다.

**문제/과제**: 처음에는 GAS AttributeSet이나 이벤트 발송 로직 문제로 오해했다.
진단 순서를 잘못 잡아 내부 로직부터 살펴봤다가 방향을 틀어야 했다.

**근본 원인**: `AddDynamic`을 `NativeConstruct`에 배치하면,
Widget을 Pool에서 꺼낼 때(재활성화 시) `NativeConstruct`가 다시 호출되어 동일 델리게이트에 중복 등록됨.

**결정**: `AddDynamic` 바인딩 전체를 `NativeOnInitialized`로 이전.
`NativeOnInitialized`는 Widget 최초 생성 시 1회만 호출되므로 재사용 시 중복 없음.

**결과/효과**: 풀링 Widget 재사용 시 이벤트 중복 실행 버그 완전 해소.
규칙으로 정착: "AddDynamic은 NativeOnInitialized에만".

**포트폴리오 포인트**: UMG Widget 생명주기 깊은 이해 / 풀링 재사용 패턴에서의 생명주기 충돌 진단

**관련 파일**: `Source/RoastStaffGAS/Private/UI/`

---

## 2026-03

### [2026-03-31] [PATTERN] UE5 빌드 셋업 함정 3가지

**상황**: 새 모듈과 UENUM을 추가하는 과정에서 컴파일 오류와 git 파싱 오류가 연달아 발생. 각각의 에러 메시지가 직접적이지 않아 진단에 시간이 걸렸다.

**함정 1 — UENUM과 .generated.h**:
UENUM()이 있는 헤더에는 반드시 `#include "파일명.generated.h"` 가 있어야 한다. 없으면 UHT 오류. 일반 `enum class`와 달리 UENUM은 UHT 코드 생성을 전제한다.

**함정 2 — UDeveloperSettings와 Build.cs**:
`UDeveloperSettings`를 상속하는 클래스 작성 시 `Build.cs`의 `PublicDependencyModuleNames`에 `"DeveloperSettings"` 모듈을 명시적으로 추가해야 한다. 누락 시 링크 오류.

**함정 3 — 한글 파일명과 UBT 크래시**:
프로젝트 경로나 애셋 이름에 한글이 포함된 경우, `git config core.quotepath false` 설정이 없으면 UBT가 git 경로를 octal 이스케이프 문자열로 파싱해 .NET 크래시 발생.

**결과/효과**: 세 가지 모두 팀 온보딩 체크리스트 수준의 비자명한 함정. 이후 새 팀원 환경 셋업 시 선제적으로 안내.

**포트폴리오 포인트**: UE 빌드 시스템 심층 이해 / 환경 셋업 트러블슈팅 경험

**관련 파일**: `RoastStaffGAS.Build.cs`, `Config/DefaultEngine.ini`

---

### [2026-03-30] [ARCH] EquipWeapon 강화 설계 — IncomingData(트리거) vs SlotData(실행) 역할 분리

**상황**: SR(2026-03-30)에서 `EquipmentSubsystem::EquipWeapon` 강화 판정 로직 리뷰 중 발견. `GetWeaponData(WeaponID, IncomingData)` 조회 후 `BaseType` 비교에만 사용하고, `NextLevelWeaponID`는 SlotData 기준으로만 처리.

**문제/과제**: 리뷰어 관점에서 들어오는 카드(IncomingData)의 `NextLevelWeaponID`를 쓰지 않는 게 의도인지 버그인지 불분명했다.

**검토한 선택지**:
  - A) 들어오는 카드(IncomingData) 기준 강화 — 새 카드의 NextLevel로 올림
  - B) 현재 슬롯(SlotData) 기준 강화 — 이미 장착된 무기의 NextLevel로 올림

**결정**: B가 올바른 설계. 기획 의도: 강화는 "현재 슬롯 무기의 레벨을 올리는 것". 들어오는 카드는 "같은 종류(BaseType) 트리거" 역할만 한다. IncomingData의 BaseType 비교 전용 사용이 정확한 설계.

**결과/효과**: 의도적 설계 확인(RESOLVED). 다만 코드에 의도 주석이 없어 리뷰어 혼란이 발생 — 변수명·주석으로 의도 명시 개선 검토.

**포트폴리오 포인트**: 기획 의도가 코드에 올바르게 반영됐는지 검증하는 리뷰 프로세스 / "트리거 역할 vs 데이터 역할" 인터페이스 설계 사고

**관련 파일**: `Source/RoastStaffGAS/Private/Subsystems/EquipmentSubsystem.cpp` (~88~105라인, EquipWeapon)

---

### [2026-03-27] [BUG_FIX] SetInputMode + SetShowMouseCursor 쌍 처리 — 수동 발사 클릭 10회 중 2회만 인식

**상황**: 수동 발사 모드에서 클릭 10회 중 2회만 `RequestManualFire`에 도달하는 버그.

**문제/과제**: 처음에는 GAS 내부 문제(`bRetriggerInstancedAbility`)로 오판, MODULE-2 코드를 수정했다가 롤백. 실제 원인은 입력 레이어였다.

**근본 원인**: 팝업 닫힐 때 `FInputModeGameOnly()` 복원 후 `SetShowMouseCursor(true)` 호출 누락. Slate가 마우스 관리권을 유지한 채 클릭을 게임에 전달하지 않음. `SetShowMouseCursor(false)` 제거 시 같은 스코프의 `SetShowMouseCursor(true)`(팝업 없음 분기)까지 함께 삭제됨 — "한 줄 삭제"가 두 분기 모두에 영향.

**검토한 선택지**:
  - A) GAS `bRetriggerInstancedAbility` 수정 — 실제 문제 레이어가 아님 (롤백)
  - B) 입력 레이어 진단: `RequestManualFire` 진입 여부 먼저 확인 → `SetInputMode` + `SetShowMouseCursor` 쌍 복원

**결정**: B. `git diff`로 최근 변경 코드를 먼저 확인했다면 첫 단계에서 원인 특정이 가능했다.

**결과/효과**: 규칙 확립: `SetInputMode` + `SetShowMouseCursor` + `SetConsumeCaptureMouseDown`은 항상 쌍으로 검토. 진단 순서 원칙: "진입점 확인 → 레이어 좁히기 → 내부 진단".

**포트폴리오 포인트**: UE5 Slate 입력 캡처 메커니즘 이해 / 잘못된 레이어 진단 → 롤백 → 올바른 순서 복구 과정 (사고 과정 투명성)

**관련 파일**: `Source/RoastStaffGAS/Private/Character/Player/RSPlayerController.cpp`

---

## [2026-04-20] PATTERN — 머티리얼 피격 플래시: Multiply vs Add 블렌딩 선택

**UE_Ver**: 5.4
**Knowledge_Risk**: LOW

**상황**: 에너미 피격 시 이미시브 붉은 플래시 연출 구현. `EmissiveIntensity` ScalarParameter를 C++에서 0→3으로 올리는 방식 채택. 머티리얼 그래프에서 `Texture_Emissive × EmissiveIntensity × Constant3Vector(1,0.3,0.3)` 구조로 연결했으나 색상 변화 없음.

**문제·과제**: EmissiveIntensity를 3으로 올려도 빨갛게 변하지 않음. Multiply 연산에서 텍스처 고유 색상 채널이 Constant3Vector를 지배하기 때문. 예: 텍스처 픽셀 `(0.5, 0.7, 0.9)` × `(1, 0.3, 0.3)` = `(0.5, 0.21, 0.27)` → 의도한 붉은빛이 아닌 탁한 색.

**검토한 선택지**:
- A) Multiply 유지 + Constant3Vector 값을 강하게 올림 → 원본 텍스처 색상이 과하게 억제됨
- B) Lerp(TextureEmissive, FlashColor, EmissiveIntensity) → 평소 이미시브가 사라지지 않지만 Saturate 처리 필요, 복잡도 증가
- C) **Add** — 기존 텍스처 이미시브 유지 + 플래시 컬러를 additive로 합산

**결정**: Add 구조 채택. `[Texture_Emissive] + [Constant3Vector × EmissiveIntensity] → Emissive Color`. EmissiveIntensity=0일 때 원본 이미시브 그대로, 피격 시 붉은빛이 텍스처 색상과 무관하게 덧씌워짐.

**결과**: 모든 에너미 머티리얼에 동일 구조 적용. C++ 코드 변경 없이 일관된 붉은 플래시 연출 확보.

**포트폴리오 포인트**: 머티리얼 그래프에서 Multiply는 "색조 필터", Add는 "발광 덧씌우기"로 동작이 근본적으로 다름. 피격·버프·상태이상처럼 원본 색상과 무관하게 일관된 이미시브를 올려야 할 때는 Add가 정답. Multiply는 텍스처의 밝기/색조를 바꿀 때 사용.

**관련 파일**: `M_HighDemon_Skin1/3`, `M_Night_Demon_Armor/Body`, `M_Skeleton_Guard_Body/Cloth`, `M_SpiderQueen`, `EnemyBaseCharacter.cpp`

---

## [2026-04-15] ARCH — UMG 툴팁 컨테이너: UBorder 대신 UOverlay 선택

**상황**: PassiveSlotWidget 툴팁 컨테이너를 초기 설계에서 UBorder로 지정. C++ 코드 작성 후 WBP 제작 단계에서 문제 발견.

**문제·과제**: Canvas Panel 위에 배치된 UBorder는 내부 TextBlock 크기에 맞게 자동 리사이징이 되지 않음. Canvas Panel 슬롯의 크기가 고정 좌표/크기로 잡히기 때문이며, Content Alignment를 Fill로 두면 부모 공간을 꽉 채워 TextBlock이 짧아도 Border가 늘어난 채로 유지됨.

**검토한 선택지**:
- A) VerticalBox/HBox 로 감싸서 Auto 슬롯 사이즈 활용 — 위젯 계층 한 단계 추가
- B) UOverlay 로 교체 — 자식 크기에 자연스럽게 맞고, Image(배경) + VerticalBox(텍스트) 레이어링도 동시에 해결

**결정**: UOverlay 채택. BindWidget 이름을 `Bdr_Tooltip → Ovl_Tooltip`으로 변경하고 C++ include도 `Border.h → Overlay.h`로 교체. WBP 계층 구조: Ovl_Tooltip(Overlay) > Image(배경) + VerticalBox > Txt_PassiveName / Txt_PassiveDesc.

**결과**: 툴팁이 내부 텍스트 길이에 맞게 자동 리사이징. Image 배경이 텍스트 영역에 정확히 맞춰짐.

**포트폴리오 포인트**: UMG 패널별 크기 결정 방식 차이를 실제 제작 중 발견하고 적용 — Canvas Panel 슬롯은 고정, Box/Overlay는 자식 크기(Auto)를 따름. 설계 단계에서 WBP 레이아웃 의존성을 미리 고려해야 C++ BindWidget 타입 선택이 흔들리지 않는다는 교훈.

**관련 파일**: `PassiveSlotWidget.h/.cpp`, `WBP_PassiveSlot`

---

## [2026-04-15] BUG_FIX — GAS Multiplicative modifier 공식 오진 → 진단 로그로 재확인

**UE_Ver**: 5.4
**Knowledge_Risk**: MEDIUM

**상황**: 패시브 GE Magnitude가 1.05~1.20이었는데 유저가 "스탯 증가폭이 의도보다 크다"고 보고. 공식을 `Base × (1 + Sum(mags))`로 분석해 magnitude를 0.05~0.20으로 변경했으나, 이후 DEF 15 → 3 (ICE_ARMOR_4, 0.20 적용)으로 오히려 대폭 감소하는 버그가 발생함.

**문제·과제**: C++ ApplyStatUpgrade 로직은 이상 없고, GE BP 설정도 시각적으로 확인 어려운 상황. 실제 GAS aggregator가 magnitude를 어떻게 처리하는지 런타임에서 직접 검증 필요.

**검토한 선택지**:
1. GE BP의 modifier 타입 확인 (Override vs Multiplicative)
2. 진단 로그 삽입으로 `GetNumericAttributeBase` vs `GetNumericAttribute` 동시 출력

**결정**: PassiveSlotSubsystem의 GE 적용 전/후에 `DEF_base`, `DEF_cur`, `ATK_cur`를 동시 로깅. 결과: `DEF_base=15.00, DEF_cur=3.00` → `15 × 0.20 = 3.00` 확인. GAS Multiplicative는 `Base × Magnitude` (Product 방식)이며, 분모에 1이 없음. magnitude 1.0x 원복.

**결과**: 패시브 ATK +20% = `Base × 1.20`, DEF +5% = `Base × 1.05`. StatUpgrade +20은 `SetNumericAttributeBase(base + 20)` 이후 aggregator 재계산 → `NewBase × 1.20`. 의도한 동작 확인.

**포트폴리오 포인트**: GAS Infinite GE의 Multiplicative modifier는 `Product(mags)` 방식 (`Base × mod1 × mod2 × ...`). 빈 상태는 1.0이 아닌 0으로 시작하지 않고, modifier 없으면 최종값 = Base 그대로. 공식 가정 전 `GetNumericAttributeBase` / `GetNumericAttribute` 쌍으로 aggregator 동작을 가시화하는 것이 가장 빠른 디버깅 패턴.

**관련 파일**: `ExternalSource/DT_Passive_Static_Data.csv`, `PassiveSlotSubsystem.cpp`, `LevelUpSubsystem.cpp`

---

## [2026-04-15] REFACTOR — 커스텀 AS 델리게이트 제거 → ASC GetGameplayAttributeValueChangeDelegate 일원화

**UE_Ver**: 5.4
**Knowledge_Risk**: LOW

**상황**: CharacterStatPopupWidget이 `PostGameplayEffectExecute` 기반의 `OnPlayerStatChangedDel`, `OnHealthChangedDel`, `OnMoveSpeedChangedDel` 커스텀 델리게이트를 구독. StatUpgrade 카드 선택 후 위젯이 갱신되지 않는 버그 발생.

**문제·과제**: `PostGameplayEffectExecute`는 Instant GE 실행 시에만 호출됨. `SetNumericAttributeBase` 경유 변경(StatUpgrade, LevelUp 시 MaxHP 갱신 등)은 감지 불가. 커스텀 델리게이트 3개가 모두 동일한 한계를 가짐.

**검토한 선택지**:
1. 수동 브로드캐스트 추가 (ApplyStatUpgrade에서 델리게이트 직접 호출)
2. ASC `GetGameplayAttributeValueChangeDelegate(Attr)` 구독 (GAS-idiomatic)

**결정**: 선택지 2 채택. 변경 경로(GE/SetNumericAttributeBase 등) 무관하게 자동 감지. 8개 어트리뷰트 모두 단일 핸들러 `OnStatChanged` → `RefreshAllStats()`로 일원화. BossEnemy HP 페이즈 전환도 동일 패턴으로 전환, `OnHealthChangedDel` 완전 제거.

**결과**: 커스텀 델리게이트 3종 제거, AttributeSet 코드 간소화. StatUpgrade/PassiveAdd/LevelUp 모든 경로에서 위젯 즉시 갱신.

**포트폴리오 포인트**: GAS에서 어트리뷰트 변경 알림은 `GetGameplayAttributeValueChangeDelegate(Attr).AddUObject()`가 idiomatic. `PostGameplayEffectExecute`는 GE 실행에만 한정. CloseUI 시 `RemoveAll(this)`로 정리하면 생명주기 안전.

**관련 파일**: `BaseAttributeSet.h/cpp`, `PlayerAttributeSet.h/cpp`, `BossEnemy.h/cpp`, `CharacterStatPopupWidget.h/cpp`

---

## [2026-04-14] ARCH — 인게임 스탯 팝업의 UMS 등록 제외 결정

**상황**: 캐릭터 어트리뷰트를 실시간으로 표시하는 팝업 UI(WBP_CharacterStatPopup)를 설계. HUD 버튼 + Tab 키로 토글되며, 게임 입력을 차단하지 않아야 함.

**문제·과제**: UMS(UIManagerSubsystem)를 통해 일반 POPUP 레이어로 등록하면 `OpenUIByID` 호출 시 `NotifyInputModeChange`가 트리거되어 GameOnly → UIOnly 전환이 발생함. 이는 "팝업 열린 채 이동/공격 가능" 요구사항과 충돌.

**검토한 선택지**:
- A) EUIID에 `CHAR_STAT_POPUP` 등록 + `bIsModal=false`로 등록 → UMS 스택 진입 시 입력 모드 변경 로직을 조건부 우회해야 함. UMS 내부 수정 필요, 부작용 범위 불명확.
- B) `UILayer=NONE`으로 HUD 자식 위젯으로 구현, UMS 미등록 → HUD 생명주기와 동기화, 입력 모드 변경 없음. `EnemyHPBarWidget` 등 기존 "UMS 제외" 위젯 패턴과 일관성 유지.

**결정**: B 채택. `UILayer=NONE` + HUD BindWidget 자식으로 배치. 토글 로직은 `URSHUDWidget::ToggleStatPopup()`에 캡슐화하고, PC의 Tab 입력과 HUD 버튼 양쪽에서 동일 함수를 호출하는 단일 경로 구조로 정리.

**결과**: 팝업 열림 상태에서 무기 자동발사·스킬 Q/E 전부 정상 동작 확인. UMS 내부 수정 없이 요구사항 충족.

**포트폴리오 포인트**: UMS 아키텍처의 입력 모드 관리 흐름을 이해하고, 기능 추가 시 기존 시스템을 수정하지 않고 "제외 패턴"을 일관되게 적용한 설계 판단.

**관련 파일**: `Public/UI/Ingame/CharacterStatPopupWidget.h`, `Public/UI/RSHUDWidget.h`

---

## [2026-04-14] BUG_FIX — PC::BeginPlay vs Character::BeginPlay 타이밍 역전으로 인한 스킬 슬롯 UI 미갱신

**상황**
캐릭터 스킬 슬롯 UI를 새로 구현. `SkillManagerSubsystem::InitializeSkills()` 완료 시 `OnSkillSlotUpdatedDel`을 브로드캐스트하고, `PC::BeginPlay`에서 구독해 UI를 갱신하는 구조.

**문제**
게임 플레이 시 캐릭터 스킬 슬롯이 항상 빈 상태로 표시됨. 로그를 확인하면 `InitializeSkills()` 브로드캐스트는 정상 발생하지만 PC가 수신하지 못함.

**원인**
UE5의 `BeginPlay` 호출 순서는 Actor 스폰 순서에 의존하며 보장되지 않음. 레벨에 Character가 이미 배치된 경우 `Character::BeginPlay → InitializeSkills → Broadcast`가 `PC::BeginPlay → 구독` 보다 먼저 실행되어 브로드캐스트를 놓침.

**해결**
두 가지 방어 코드 추가:
1. `SlotContainerWidget::NativeConstruct()`에서 모든 슬롯에 `UpdateSlot(nullptr)` 호출 → 초기 상태를 Collapsed로 보장
2. `PC::BeginPlay`에서 HUD 오픈 직후 `RefreshSkillSlotUI(0~1)` 강제 호출 → 이미 초기화된 경우 즉시 UI 반영

**포트폴리오 포인트**
UE5의 BeginPlay 순서 비보장 특성. 이벤트 드리븐 초기화만 믿지 않고, "구독 후 현재 상태 풀링(pull)"을 병행하는 패턴이 안전. 이는 옵저버 패턴의 "missed notification" 문제에 대한 일반적 해법.

**관련 파일**
- `Private/Subsystems/SkillManagerSubsystem.cpp` — InitializeSkills Broadcast 추가
- `Private/UI/Ingame/SlotContainerWidget.cpp` — NativeConstruct 초기 Collapsed
- `Private/Character/Player/RSPlayerController.cpp` — BeginPlay force-refresh

---

## [2026-04-13] PATTERN — UGameplayEffectExecutionCalculation (ExecCalc) 구조와 Static Capture 패턴

**상황**: M-4에서 플레이어→에너미, 에너미→플레이어 데미지를 단일 GE에서 분기 처리해야 했다. 기존 방식은 Modifier 방향을 SetByCaller 음수값(−DamageValue)으로 직접 조작하는 간이 구조였다.

**문제·과제**: Modifier-only GE는 ATK/DEF 같은 Attribute를 공식 내에서 읽을 수 없다. 크리티컬, DEF 감산 등 복잡한 공식을 GE 내부에서 계산하려면 GAS가 공식 지원하는 `UGameplayEffectExecutionCalculation`이 필요.

**검토한 선택지**:
- A) Modifier Stack — SetByCaller 음수 직접 주입. GE 설정 단순, 공식 확장 불가
- B) MMC (Magnitude Modifier Calculation) — 단일 Attribute 계산. 다중 Attribute 조합 불가
- C) ExecCalc (`UGameplayEffectExecutionCalculation`) — 다중 Attribute 캡처 + 임의 공식 + 다중 Attribute 출력 가능. 구조 복잡하나 GAS 공식 패턴

**결정**: C 선택. 핵심 패턴 3가지:
1. `FDamageExecCaptures` 정적 구조체 — `DECLARE/DEFINE_ATTRIBUTE_CAPTUREDEF` 매크로로 캡처 정의. `bSnapshot=false`로 실행 시점 라이브 값 캡처.
2. `Execute_Implementation` 내 Source 팀 태그 분기 — `CapturedSourceTags.GetAggregatedTags()->HasTagExact(Team_Player)`로 플레이어/에너미 방향 판별.
3. `OutExecutionOutput.AddOutputModifier` — `EGameplayModOp::Additive`로 CurrentHP에 `-FinalDamage` 출력.

**결과**: 플레이어→에너미 `BaseDmg×(1+ATK/100)×CritMult`, 에너미→플레이어 `max(1, EnemyDmg-DEF)` 두 공식을 단일 ExecCalc 클래스에서 처리.

**포트폴리오 포인트**: GAS 데미지 공식 설계의 세 단계(Modifier→MMC→ExecCalc) 이해와 적합한 계층 선택 / `DECLARE_ATTRIBUTE_CAPTUREDEF` + static struct 패턴 실전 적용.

**관련 파일**: `Source/RoastStaffGAS/Public/GAS/Calculations/RS_DamageExecCalc.h`, `Private/GAS/Calculations/RS_DamageExecCalc.cpp`

---

## [2026-04-13] ARCH — SetByCaller 태그 분리: Data_Damage 단일 → WeaponBaseDamage/EnemyAttackDamage

**상황**: 기존 모든 데미지(플레이어 무기, 에너미)가 `Data.Damage` 단일 태그에 음수값으로 주입됐다. ExecCalc 도입 시 Source 방향을 구분해야 하는데, 단일 태그로는 ExecCalc 내부에서 "누가 보낸 데미지인가"를 태그 없이 판단해야 함.

**문제·과제**: ExecCalc에서 Source ASC 팀 태그로 분기는 가능하나, SetByCaller 값 의미(양수 BaseDmg vs 음수 Modifier)가 혼재해 공식에 혼란이 생김. ExecCalc 내부에서 `-음수`를 다시 양수로 뒤집는 이중 부정이 발생.

**결정**: 태그 분리 + 양수 전달 원칙 확립.
- 무기(플레이어): `Data.WeaponBaseDamage` — 양수 BaseDmg 주입
- 에너미: `Data.EnemyAttackDamage` — 양수 AttackDmg 주입
- ExecCalc 출력 시 `-FinalDamage`로 HP 감산

**결과**: `GetSetByCallerMagnitude` 호출 태그가 Source 유형을 의미상으로 명시. ExecCalc 내 이중 부정 제거. 6개 파일 일괄 교체(BaseProjectile, BaseSummonObject, 에너미 4종).

**포트폴리오 포인트**: GAS 데이터 흐름 설계 — "입력은 양수, 출력에서 방향 결정" 원칙 / SetByCaller 태그 네이밍이 의미 전달하도록 분리하는 인터페이스 설계 사고.

**관련 파일**: `RSGameplayTags.h/.cpp`, `BaseProjectile.cpp`, `BaseSummonObject.cpp`, `MeleeEnemy.cpp`, `EliteEnemy.cpp`, `BossEnemy.cpp`, `EnemyProjectile.cpp`

---

## [2026-04-13] PATTERN — SUMMON 타입 자동발사에서 LocalInputConfirm 자동 호출

**상황**: M-3 자동발사 전환 시 SUMMON 타입 무기(召喚物을 일정 위치에 배치하는 GA)가 `WaitForPlayerConfirm` Task에서 무한 대기하는 문제. 수동 발사 모드에서는 플레이어 클릭이 `LocalInputConfirm`을 트리거했으나, 자동발사 모드에서는 클릭 입력이 없다.

**문제·과제**: `FireSlot` 호출 후 GA가 `WaitForPlayerConfirm` 상태에 멈춰 있으면 타이머 다음 틱에 동일 슬롯의 새 GA를 활성화하지 못하고 자동발사 루프가 정지.

**검토한 선택지**:
- A) SUMMON GA 내부에 타임아웃 추가 — GA 변경 필요, 다른 활성화 경로(수동 미래 지원)에 영향
- B) `StartAutoFire` 타이머 내에서 `FireSlot` 직후 `ASC->LocalInputConfirm()` 자동 호출 — 호출 측에서 처리, GA 무수정

**결정**: B 선택. `TriggerAbilityFromGameplayEvent`가 동기 처리되므로, `FireSlot` 반환 시점에 GA는 이미 `WaitForPlayerConfirm` 상태. 그 직후 `LocalInputConfirm()` 호출이 정확히 해당 대기를 해제.

**결과**: SUMMON 타입도 자동발사 루프 정상 동작. GA 코드 무수정.

**포트폴리오 포인트**: GAS `LocalInputConfirm`의 동작 시점 이해 / 자동화 컨텍스트에서 GA 내부를 변경하지 않고 호출 측에서 흐름을 제어하는 설계 판단.

**관련 파일**: `Source/RoastStaffGAS/Private/Subsystems/EquipmentSubsystem.cpp` (StartAutoFire 타이머 람다)

---

## [2026-04-13] ARCH — DT_CharacterSkill 스키마: 중첩 배열 vs 분리 테이블

**상황**: 캐릭터 고유 스킬의 레벨별 수치(Lv1/2/3 — DamageMultiplier, EffectRadius, Duration, FXClass)를 DataTable에 담는 방식 결정. 스킬당 3레벨, 캐릭터당 2슬롯의 소규모 데이터.

**문제·과제**: 두 가지 설계 선택지 존재.
- A안: `FCharacterSkillStaticData` 내 `TArray<FCharacterSkillLevelData>` 중첩 — 1테이블, 에디터 인라인 편집 가능. 단, CSV 임포트 불가(UE CSV는 중첩 배열 미지원).
- B안: `DT_CharacterSkillLevel` 별도 분리 — CSV 완전 지원. 단, 테이블 2개 + GDS 조회 시 JOIN 필요, 캐릭터 스킬 추가마다 두 테이블 모두 관리해야 하는 운영 부담 증가.

**검토한 선택지**: A안 vs B안. 핵심 기준은 데이터 규모, 편집 빈도, 조회 복잡도.
- 스킬 수: 캐릭터 수 × 2 = 최대 30개 내외 → 대규모 CSV 배치 임포트 불필요
- Lv1~3 데이터는 스킬 설계 시 한 번에 확정되고 이후 거의 수정 없음 → 빈번한 CSV 업데이트 불필요
- B안의 JOIN 조회는 `GetCharacterSkillExecData` 로직을 복잡하게 만들고 DT 행 수 3배 증가

**결정**: **A안 채택** — `TArray<FCharacterSkillLevelData>` 중첩 유지. DT_CharacterSkill은 에디터 직접 편집으로 관리, CSV 임포트 대상에서 제외.

**결과**: GDS 조회 `GetCharacterSkillExecData(CharID, Slot, Level)` 단일 함수로 Level 클램프+LevelData 인덱싱까지 처리. 테이블 1개, 조회 경로 단순.

**포트폴리오 포인트**: DataTable 아키텍처 설계 — "데이터 규모·편집 패턴·조회 복잡도" 세 기준으로 CSV 파이프라인 vs 에디터 직접 편집을 선택하는 판단 근거. UE DataTable의 CSV 제약(중첩 배열 미지원)을 인지하고 시스템별 적합한 편집 워크플로를 구분한 사례.

**관련 파일**: `DataTableStructs.h` (FCharacterSkillStaticData), `GameDataSubsystem.cpp` (GetCharacterSkillExecData), `ExternalSource/DT_Character_Skill_Static_Data.csv`

---

## [2026-04-09] ARCH — 보스 HP Bar 위젯 이중 Close 타이밍 충돌 처리

**상황**: 보스 HP Bar(WBP_BossHPBar)는 HP=0 감지 시 FadeOut 애니메이션을 재생하고, 완료 후 UIManagerSubsystem에 정리를 요청하는 구조. 그러나 보스 사망 이벤트(OnBossKilled)가 FadeOut 도중 EnemySpawner에 먼저 도달해 `CloseUIByID`를 즉시 호출하면 FadeOut이 강제 중단되고, UMS의 `CloseUIInternal` 이 `RemoveFromParent`까지 즉시 실행해 애니메이션이 끊기는 문제가 존재.

**문제·과제**: 위젯이 FadeOut을 자율적으로 처리하면서도 UMS의 PERSISTENT 레이어 정리(PersistentUIMap cleanup)까지 보장해야 함. `CloseUI()` 오버라이드만으로는 UMS가 `CloseUI` 직후 `RemoveFromParent`를 호출하는 구조를 막을 수 없음.

**검토한 선택지**:
- `CloseUI()` 오버라이드: FadeOut 재생 후 `Super::CloseUI()` 반환 → UMS가 바로 `RemoveFromParent` 호출해 효과 없음
- `mutable bIsClosing` + EnemySpawner 게이트: EnemySpawner가 `IsClosing()` 확인 후 `CloseUIByID` 스킵 → FadeOut 완료 후 위젯이 UMS에 직접 `CloseUIByID` 요청, UMS가 정상 정리 수행

**결정**: `bIsClosing` 플래그를 위젯 내부에 두고, EnemySpawner가 `TWeakObjectPtr<UBossHPBarWidget>` 캐시로 상태를 조회. FadeOut 완료 시 위젯이 `GetWorld()->GetGameInstance()`를 통해 UMS `CloseUIByID`를 직접 호출해 PersistentUIMap 정리까지 보장.

**결과**: FadeOut 중 `OnBossKilled` 도달 시 EnemySpawner 게이트에서 `CloseUIByID` 스킵. FadeOut 없는 경우(Anim_FadeOut 미설정)는 EnemySpawner 폴백 경로로 즉시 정리. 두 경로 모두 UMS 정리 완결.

**포트폴리오 포인트**: 위젯-UMS 간 비동기 생명주기 충돌을 플래그+캐시 조합으로 조율. UMS `CloseUIInternal`의 `CloseUI → RemoveFromParent` 즉시 호출 구조를 분석하고, 위젯 자율 종료 패턴과 UMS 중앙 관리 원칙을 모두 만족하는 설계를 도출한 사례.

**관련 파일**: `Source/RoastStaffGAS/Public/UI/Enemy/BossHPBarWidget.h`, `Source/RoastStaffGAS/Private/System/EnemySpawner.cpp`

---

## [2026-04-22] BUG — 스테이지 클리어 후 로비 복귀 시 쿨타임 타이머 dangling 크래시

**상황**: 스킬 사용 중 스테이지를 클리어하면 로비로 레벨 전환되면서 에디터가 크래시. 스택 트레이스 최심단은 `USkillManagerSubsystem::StartCooldown` 내부 람다 → `OnSkillSlotUpdatedDel.Broadcast` → `ProcessMulticastDelegate` → `ConstructItems`(메모리 손상).

**문제·과제**: `StartCooldown`의 쿨타임 만료 타이머 람다가 raw `this`를 캡처. 레벨 전환 시 `USkillManagerSubsystem`(WorldSubsystem)은 소멸 경로에 진입하는데, `Deinitialize()` 오버라이드가 없어 타이머가 정리되지 않음. 타이머가 만료되면 소멸된 서브시스템의 `OnSkillSlotUpdatedDel`에 접근 → 델리게이트 내부 배열 오염 → `ConstructItems` 크래시.

**검토한 선택지**:
- A) `Deinitialize()`만 추가해 타이머를 강제 정리 — 타이머가 Deinitialize 이전에 만료될 경우 여전히 raw `this` 위험 잔존
- B) 람다만 `TWeakObjectPtr`로 교체 — 리스너(PC)가 소멸된 경우 델리게이트 오염 경로 차단 불완전
- C) 두 가지 모두 적용 — `Deinitialize()`에서 타이머 전체 Clear + 델리게이트 Clear, 람다는 `TWeakObjectPtr<USkillManagerSubsystem>` + `IsValid()` 가드

**결정**: C안 채택. `Deinitialize()`는 월드 해체 시 타이머와 델리게이트를 일괄 정리하는 방어선, `TWeakObjectPtr` 가드는 그 사이 타이머가 만료될 경우를 대비하는 이중 안전망. `PullVortexActor`가 이미 `TWeakObjectPtr` 패턴으로 동일 문제를 방지하고 있었음 — 서브시스템에도 동일 원칙 확산 적용.

**결과**: 레벨 전환 시 `Deinitialize()`에서 6개 슬롯 `CooldownTimer` 전부 `ClearTimer` → `OnSkillSlotUpdatedDel.Clear()` → `ASC = nullptr` → `bIsInitialized = false` 순으로 정리. 이후 람다가 실행되더라도 `WeakThis.IsValid()` false 분기에서 즉시 return.

**포트폴리오 포인트**: UE WorldSubsystem 생명주기와 TimerManager 정리 타이밍 이해 — `Deinitialize()` 미구현 시 레벨 전환 중 타이머 dangling이 발생하는 구조적 원인 분석. `TWeakObjectPtr` 이중 안전망 패턴을 프로젝트 내 일관 적용(PullVortexActor 선례 → SkillManagerSubsystem 확산).

**관련 파일**: `Source/RoastStaffGAS/Public/Subsystems/SkillManagerSubsystem.h`, `Source/RoastStaffGAS/Private/Subsystems/SkillManagerSubsystem.cpp`

---

<!-- 새 항목은 가장 최근 날짜가 위로 오도록 추가 -->