---
name: 학습자 성장 궤적 및 핵심 취약 패턴
description: SR 기반 반복 지적 패턴 추이, 극복 영역, 잔류 취약점 — 학습 리포트 생성 시 필수 참조
type: user
---

## 핵심 취약 영역 (반복 미해결)

### 1. 하드코딩 수치 — 4회차 (GA_Base::SPAWN_OFFSET)
- 동일 파일, 동일 상수가 4회 연속 지적. 단순 망각이 아닌 인식 문제
- 학습 리포트에서 매번 최우선 항목으로 강조 필요

### 2. UPROPERTY TMap 누락 — 3회차 재발 (ActorPool)
- SR_0330에서 "극복 판정"했으나 SR-FULL_0408에서 PoolingSubsystem::ActorPool 동일 위치 재발
- 극복 판정 취소. "신규 컨테이너 추가 시 확인"은 되나 "기존 컨테이너 재검토"는 누락

### 3. USTRUCT 기본값 미설정 — 2회차 (부분해결)
- Pierce/Homing 해결됨. FWeaponStaticData 등 12필드 잔류

## 신규 발견 (SR-FULL_0408)

### Enemy 계층 추상화 누락
- 플레이어 측 GA_Base 패턴은 습득, Enemy 측 확장 시 복사-붙여넣기로 회귀
- Template Method Pattern 적용 필요

### constexpr 타입 불일치
- `constexpr int32 = 80.f` — 컴파일러 경고 무시 패턴

## 극복 확인 (SR-FULL_0408 기준)
- switch fall-through: RESOLVED
- OnPoolDeactivate 리셋: RESOLVED (3종 모두)
- NativeOnInitialized AddDynamic (위젯 레벨): RESOLVED
- Clean Architecture 의존 방향: 120+ 파일 규모 위반 없음 확인

## 학습 리포트 생성 시 주의사항
- 하드코딩 4회차는 매 리포트에서 최우선 필수 학습 항목으로 배치
- UPROPERTY 극복 판정은 신중히 — ActorPool 동일 위치 3회 재발 이력 있음
- Enemy 측 추상화는 플레이어 측 패턴과 대칭으로 설명하면 이해 빠름
