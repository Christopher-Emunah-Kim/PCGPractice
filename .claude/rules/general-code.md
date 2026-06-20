# 일반 코딩 컨벤션
> 적용 경로: Source/**
> 모든 C++ 파일 작업 시 기본 적용

## 필수 패턴

```cpp
// ❌ 중괄호 없는 인라인 if
if (!Component) return;

// ✅ 항상 중괄호
if (!Component)
{
    return;
}
```

## 로깅

```cpp
// ✅ 프로젝트 로그 카테고리 사용 (PCGPractice.h 정의)
UE_LOG(LogPCGPractice, Warning, TEXT("Component is null"));
UE_LOG(LogPCGPractice, Error, TEXT("Failed to initialize: %s"), *Name);

// ❌ LogTemp 사용 금지 — 필터링 불가
UE_LOG(LogTemp, Warning, TEXT("..."));
```

## NULL 체크 계층

| 레벨 | 사용처 | 코드 |
|------|--------|------|
| L1 — 일반 유효성 | 런타임 null 가능 | `if (!ptr) { UE_LOG(...); return; }` |
| L2 — 필수 존재 | 반드시 있어야 함 | `check(ptr)` 또는 `ensureMsgf(ptr, TEXT("..."))` |

## GC 참조 규칙

- UObject* / Actor* / Component* 멤버 변수 → `UPROPERTY()` 필수
- 런타임 데이터 오브젝트 → `UPROPERTY()` 강참조로 GC 추적

## 설계 원칙

- **단일 책임** — 함수는 한 가지 일만
- **Variant 독립성** — Variant_Combat / Variant_SideScrolling / Variant_Platforming 간 직접 의존 금지
  - 공통 로직은 PCGPracticeCharacter 또는 별도 공통 헤더로 분리
- **실험 코드 표시** — 학습·실험 목적 임시 코드는 `// EXPERIMENT:` 주석으로 표시

## Private 헬퍼 배치 원칙

```
"이 함수가 이 클래스의 동작을 설명하는가?" → YES → 헤더 private 선언
"단순 데이터 변환/조회인가?"              → 조건부 → anonymous namespace 가능

anonymous namespace 허용 조건:
  - 해당 클래스와 무관한 순수 유틸리티
  - 클래스 멤버에 접근하지 않음
  - 2개+ 클래스 공유 가능성 → 별도 헤더로 분리
```

## 네트워크 코드

- 싱글플레이어 학습 프로젝트 — Replication / RPC 코드 추가 금지

## 새 요소 추가 체크리스트

코드 작성 전 반드시 확인:
- [ ] 어느 Variant에 속하는 코드인가 (또는 공통인가)
- [ ] 새 C++ 클래스 생성 필요 여부
- [ ] UObject* 멤버에 UPROPERTY() 붙었는가
- [ ] 에디터 설정 (BP/에셋) 필요 여부
