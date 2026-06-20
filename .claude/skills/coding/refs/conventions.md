# 코딩 컨벤션 상세

## 예외처리 계층
### 계층 1 — 일반 유효성 체크 (디버깅용)
LoggingSystem.h를 참고한다. 일반 UE_LOG는 사용하지 않는다.
```cpp
if (!SkillData)
{
    KHS_WARN(TEXT("SkillData is null"));
    return;
}
```

### 계층 2 — 중요 인스턴스 (반드시 존재해야 하는 것)
```cpp
check(SkillData);
// 또는
ensureMsgf(SkillData, TEXT("SkillData must not be null"));
```

## 클래스 네이밍 컨벤션

- UE5 표준 타입 접두어만 사용: `A`(Actor), `U`(UObject/Widget), `F`(Struct), `E`(Enum), `I`(Interface)
- **프로젝트 접두어(RS) 신규 클래스에 금지** — `ALobbyCharacterActor` ✅ / `ARSLobbyCharacterActor` ❌
- 기존 RS 접두어 클래스(ARSOutGamePlayerController 등)는 리네임 없이 유지

## 금지사항

```cpp
// ❌ 절대 금지: GET_GI_SUBSYSTEM 매크로 뒤 세미콜론
GET_GI_SUBSYSTEM(URSGameDataSubsystem, GDS);

// ✅ 올바른 사용 (세미콜론 없음)
GET_GI_SUBSYSTEM(URSGameDataSubsystem, GDS)

// ❌ 절대 금지: 중괄호 없는 인라인 스타일
if (!SkillData) return;

// ✅ 모든 if문은 반드시 중괄호로 묶는다
if (!SkillData)
{
    return;
}

//하드코딩 금지
- 대상 - DataTable/EditDefaultsOnly
```

## 일반 규칙
- **SOLID 원칙** 준수
- **함수형 프로그래밍 / 객체지향 프로그래밍** 준수
- **비즈니스 로직 / 표현-연출 로직** 필수 분리
- **조합메서드 패턴** 준수
- **하드코딩 금지.** 수치와 규칙은 항상 DataTable 또는 외부 데이터에서 참조.
- **GAS 소유권 패턴:**
  - Player ASC → PlayerState 소유 (사망 후에도 유지)
  - Enemy ASC → Enemy Actor 직접 소유 (사망 시 소멸)
- **GA 트리거:** `SendGameplayEventToActor` 사용 (`TryActivateAbilityByHandle` 아님)
- **네트워크 코드** 주석 처리 유지 (싱글플레이어 프로젝트)
- **CSV 인코딩:** UTF-8-BOM 필수

## Private 헬퍼 배치 원칙

```
헤더 private 선언 필수:
  - 클래스 멤버 함수는 예외 없이 헤더 private에 선언
  - 헤더만 읽어도 내부 호출 흐름을 파악할 수 있어야 함

cpp-only 자유 함수 허용 조건 (anonymous namespace):
  - 해당 클래스와 무관한 순수 유틸리티 (타입 제네릭 등)
  - 클래스 멤버에 접근하지 않음
  - 2개 이상의 클래스에서 공유할 가능성이 있으면 별도 헤더로 분리

판단 기준 요약:
  "이 함수가 이 클래스의 동작을 설명하는가?" → YES → 헤더 private
  "단순 데이터 변환/조회인가?"              → NO  → anonymous namespace 가능
```

## GC 참조 규칙

- `FGameplayAbilitySpec.SourceObject`는 약참조(Weak)이므로 런타임 데이터 오브젝트 보관에 불충분
- 런타임 데이터 오브젝트는 반드시 `UPROPERTY()` 강참조로 유지

## 새 요소 추가 시 영향 범위 체크리스트

코드 작성 전 반드시 확인:
- CSV/DataTable 수정 필요 여부
- 새 C++ 클래스 생성 필요 여부
- 기존 클래스 수정 필요 파일 목록
- Gameplay Tag 추가 필요 여부
- 에디터 설정(BP/에셋) 필요 여부
