# LEARN — 2026-04-15 PassiveSlotUI

SR 파일: `_Design/Reviews/SR_20260415_PassiveSlotUI.md`
PLAN: PLAN_PassiveSlotUI_v1.0
평가: 기획서정합 4/5 | UMG 4/5 | 메모리 5/5 | OOP 4/5 | 컨벤션 4/5

---

## 필수 학습 (수정 권고 + 지식 공백 교차)

| 키워드 | 개념 | 왜 중요한가 | 출처 |
|--------|------|-------------|------|
| ensureMsgf-nullptr-guard | ensureMsgf는 Shipping 빌드에서 false 반환 시 실행을 멈추지 않음. 조건 실패 후 역참조가 이어지면 크래시 | Shipping 배포 시 guard 없는 역참조는 실제 크래시로 이어짐. 패턴 불일관성은 코드 리뷰 시 신뢰도 하락 | SR HIGH [CODE] |
| include-path-case-sensitivity | UI/Ingame vs UI/InGame — 대소문자 혼용은 Linux/Mac 빌드에서 컴파일 에러 | 크로스 플랫폼 빌드 시 case-sensitive 파일시스템에서 해당 #include가 찾히지 않음 | SR LOW, RECURRING 1회 진입 |

---

## 심화 권장 (개선 제안 + 애매해 항목)

| 키워드 | 현재 수준 | 목표 수준 |
|--------|-----------|-----------|
| LoadSynchronous + UPROPERTY GC 강참조 | 애매해 — 설명 후 이해 (이번 세션) | LoadSynchronous 반환값을 UPROPERTY 멤버에 저장하지 않으면 GC가 즉시 수거할 수 있음을 즉답 가능 |
| UpdateSlot 교체 시나리오 — icon null 방어 | 인지 부족 — SR MED 지적 | ClearSlot에서 브러시 리셋 또는 else 브랜치에서 빈 브러시 세팅 패턴을 자력 도출 가능 |
| UMG Visibility 3종 구분 (Collapsed/Hidden/SelfHitTestInvisible) | 학습중 (2026-04-14 1회 애매해) | 세 가지를 시나리오별로 즉답 가능 |

---

## 성장 확인 (이전 → 이번)

| 항목 | 이전 | 이번 |
|------|------|------|
| UPROPERTY GC 추적 | 2회 지적 (RECURRING) | 완전 클리어 — LoadedPassiveIcon 포함 모든 멤버 정상 적용 |
| AddDynamic NativeOnInitialized | 자기주도 발견 후 교정 (2026-03-27) | 완벽 준수 — RESOLVED 확정 |
| NativeOnInitialized vs NativeConstruct 이해 | 학습 필요 (2026-03-27 미숙) | 즉답 가능 (EX #1 알아 ✓) |
| GetWidgetByID vs OpenUIByID 의도 구분 | 미확인 | 즉답 가능 (EX #4 알아 ✓) |
| BindWidget + switch vs TArray 이유 | 미확인 | 즉답 가능 (EX #5 알아 ✓) |

---

## 학습 순서 제안

KnowledgeGaps 누적 기반 — 이걸 알아야 저걸 이해한다 순서

1. **ensureMsgf 동작 원리** → **nullptr guard 패턴** → **Shipping 빌드 차이**
   이유: ensure 계열 함수가 개발 빌드에서만 assert처럼 동작한다는 사실을 모르면 "guard 추가했으니 안전하다"는 과신이 생김. 실제 Shipping 동작을 이해한 뒤 방어 패턴을 선택해야 의미 있음.

2. **LoadSynchronous 반환값 생명주기** → **UPROPERTY GC 강참조**
   이유: 로컬 변수에 담은 UObject*는 해당 함수가 끝나면 GC 대상이 됨. UPROPERTY 멤버에 저장해야 강참조가 유지됨을 체화해야 LoadSynchronous 패턴을 자력으로 올바르게 작성할 수 있음.

3. **UMG Visibility 3종** → **UpdateSlot 방어적 상태 리셋 패턴**
   이유: Collapsed/Hidden/SelfHitTestInvisible 구분이 명확해야 슬롯 교체 시나리오에서 "어떤 Visibility를 초기값으로 써야 하는가"를 자력 결정할 수 있음.

4. **include 경로 대소문자** → **크로스 플랫폼 빌드 주의점**
   이유: Windows는 case-insensitive이므로 로컬에서 빌드가 통과해도 Linux 서버나 Mac에서 실패함. 이 사실을 알아야 PR 전 자가 체크 습관이 생김.

---

## 이전 대비 점수 변화

| 항목 | SR_20260408_SRFULL | SR_20260415_PassiveSlotUI | 변화 |
|------|-------------------|--------------------------|------|
| 메모리 | 4/5 (UPROPERTY-TMap 미해결) | 5/5 | +1 — UPROPERTY 완전 해소 |
| UMG | (해당 없음) | 4/5 | 신규 측정 |
| OOP | (해당 없음) | 4/5 | 신규 측정 |
| 기획서정합 | 4/5 | 4/5 | 유지 (PLAN vs 실구현 오차 1건) |
| 컨벤션 | (해당 없음) | 4/5 | 신규 측정 — include 혼용 감점 |

---

## 다음 세션 전 체크리스트

- [ ] ensureMsgf 뒤에는 반드시 if guard 또는 early return — ensure 없이 역참조하는 라인이 없는지 확인
- [ ] #include 경로 대소문자 — 실제 디렉터리 이름과 완전히 일치하는지 커밋 전 grep
- [ ] UpdateSlot 에서 icon null 시 else 브랜치 빈 브러시 세팅 또는 ClearSlot 일원화
- [ ] LoadSynchronous 반환값은 UPROPERTY 멤버에 저장 — 로컬 변수 저장 금지
- [ ] UMG Visibility 3종 즉답 연습 (Collapsed/Hidden/SelfHitTestInvisible 시나리오별 선택)

---

## 자기주도 극복 패턴 (주목)

이번 세션에서 UPROPERTY GC 추적과 NativeOnInitialized 두 항목이 동시에 RESOLVED 확정되었다. 두 항목 모두 SR 지적 후 자기주도 발견 + 반복 체크 과정을 거쳐 완전히 체화된 패턴임. ensureMsgf-nullptr-guard는 같은 방식으로 접근하면 다음 세션에서 RESOLVED 전환 가능.
