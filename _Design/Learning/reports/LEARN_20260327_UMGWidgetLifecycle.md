# LEARN — 2026-03-27 UMG Widget Lifecycle

> 출처: LevelUpWeaponSelectWidget 버그 수정 경험 (직접 학습)
> SR 연계: 없음 (자기주도 학습)

---

## 버그 요약

UIManagerSubsystem이 LevelUpWeaponSelectWidget을 캐시하여 재사용.
AddToViewport 재호출 시 NativeConstruct가 다시 실행되어 버튼 AddDynamic이 중복 등록됨.
결과: EquipAndClose가 두 번 호출 → 두 개의 슬롯에 무기 장착.

---

## 필수 학습 (수정 권고 수준 — 재사용 위젯 버그 원인)

| 키워드(영어) | 개념 | 왜 중요한가 |
|---|---|---|
| NativeConstruct | AddToViewport 될 때마다 재호출. 위젯이 화면에 나타날 때마다 실행 | 캐시/풀링 재사용 시 AddDynamic을 여기에 두면 중복 바인딩 버그 발생 |
| NativeOnInitialized | 위젯 객체 최초 생성 시 딱 1회만 호출. CreateWidget 시점에 실행 | 버튼 AddDynamic, 컴포넌트 참조 초기화 등 1회성 설정의 정확한 위치 |
| AddDynamic duplicate binding | 같은 델리게이트에 같은 함수를 두 번 이상 바인딩하면 콜백이 중복 실행됨 | 유사 버그는 언제나 AddDynamic 위치를 먼저 의심해야 함 |
| Widget caching / pooling | UIManagerSubsystem 등이 위젯 인스턴스를 캐시하면 CreateWidget이 재호출되지 않음 | NativeOnInitialized는 1회, NativeConstruct는 N회 — 이 차이를 항상 전제해야 함 |

---

## 심화 권장 (개선 제안 수준)

| 키워드(영어) | 현재 수준 | 목표 수준 |
|---|---|---|
| NativeDestruct | 호출 시점 불명확 | RemoveFromParent 시 호출 확인, 클린업 로직 배치 기준 수립 |
| Construct vs Initialize execution order | 순서 미숙지 | NativeOnInitialized → NativePreConstruct → NativeConstruct 순서 암기 |
| IsDynamic binding check (IsBoundToObject) | 미사용 | 중복 바인딩 방어를 위한 바인딩 여부 사전 확인 패턴 학습 |
| UUserWidget lifecycle vs UActorComponent lifecycle | 혼용 위험 | 위젯과 컴포넌트의 생명주기 메서드 대응표 숙지 |

---

## 성장 확인 (이전 대비 개선)

| 항목 | 이전 | 이번 |
|---|---|---|
| 버그 원인 파악 방식 | 증상(무기 2회 장착)에서 원인(중복 바인딩) 추적 느림 | 생명주기 메서드 재호출을 원인으로 정확히 특정 |
| 자기주도 수정 | SR 지적 후 수정 | 버그 재현 → 원인 분석 → 수정 → 학습 목표화까지 자체 완결 |

---

## 핵심 규칙 (3줄 요약)

```
1. AddDynamic은 NativeOnInitialized에만 넣는다 — 재사용 위젯에서 NativeConstruct는 N회 실행된다.
2. NativeConstruct는 "화면에 뜰 때마다 갱신해야 하는 것"만 넣는다 (상태 리셋, 데이터 바인딩 갱신).
3. 위젯이 캐시/풀링되는지 여부를 항상 먼저 확인하고 초기화 위치를 결정한다.
```

---

## 이전 대비 점수 변화

| 항목 | 이전 (Pierce SR) | 이번 (자기주도) |
|---|---|---|
| UMG 생명주기 이해도 | 미측정 | 버그 수정 완료 → 실전 적용 확인 |
| 자기주도 버그 발견 | 0건 → 2건 (SR_2026-03-24 이후 개선) | 위젯 생명주기 버그 자체 발견 및 수정 |

---

## 다음 세션 전 체크리스트

- [ ] NativeOnInitialized / NativeConstruct / NativeDestruct 호출 시점 코드로 직접 검증 (로그 찍기)
- [ ] 프로젝트 내 다른 위젯에서 AddDynamic 위치 전수 점검
- [ ] UIManagerSubsystem 캐시 위젯 목록 확인 — 동일 버그 패턴 존재 여부 검토
- [ ] IsBoundToObject 방어 코드 패턴 실습
