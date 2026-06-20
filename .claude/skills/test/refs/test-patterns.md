# UE5 즉석 테스트 패턴 가이드

## 테스트 진입점 패턴

### 1. BeginPlay 임시 호출
가장 간단한 방식. GameMode 또는 테스트 전용 Actor의 BeginPlay에 호출 코드를 삽입한다.

```cpp
void AMyGameMode::BeginPlay()
{
    Super::BeginPlay();
    
    // ===== 테스트 코드 시작 =====
    TestWeaponEquip();
    // ===== 테스트 코드 끝 =====
}

void AMyGameMode::TestWeaponEquip()
{
    UE_LOG(LogTemp, Warning, TEXT("=== TestWeaponEquip START ==="));
    // 테스트 로직
    UE_LOG(LogTemp, Warning, TEXT("=== TestWeaponEquip END ==="));
}
```

### 2. 콘솔 명령어 방식
에디터에서 `~` 키로 콘솔을 열고 명령어로 테스트 함수를 호출한다.

```cpp
// .h
UFUNCTION(Exec)
void TestSkillActivation(int32 SkillID);

// .cpp
void AMyPlayerController::TestSkillActivation(int32 SkillID)
{
    UE_LOG(LogTemp, Warning, TEXT("Testing Skill ID: %d"), SkillID);
    // 테스트 로직
}
```

### 3. 에디터 유틸리티 위젯
Blueprint에서 버튼 클릭으로 C++ 함수를 호출하는 방식.
복잡한 시나리오나 반복 테스트에 유용하다.

## 더미 데이터 패턴

### CSV 더미 행
기존 DataTable CSV에 테스트 행을 추가한다. 테스트 완료 후 제거.

```csv
Name,WeaponID,Damage,CoolTime
"TEST_Sword_001",9901,100,1.5
"TEST_Staff_001",9902,80,2.0
```

규칙: 테스트 데이터의 ID는 9900번대를 사용하여 실제 데이터와 구분한다.

## UE_LOG 출력 패턴

테스트 로그는 일관된 형식으로 출력하여 결과 대조를 쉽게 한다:

```cpp
// 테스트 시작/종료 마커
UE_LOG(LogTemp, Warning, TEXT("=== [TC-01] START: WeaponEquip Normal Flow ==="));

// 단계별 진행 로그
UE_LOG(LogTemp, Warning, TEXT("[TC-01] Step 1: DataTable lookup - WeaponID=%d"), WeaponID);
UE_LOG(LogTemp, Warning, TEXT("[TC-01] Step 2: Component creation - Success=%s"), bSuccess ? TEXT("true") : TEXT("false"));

// 결과 로그
UE_LOG(LogTemp, Warning, TEXT("[TC-01] RESULT: %s"), bAllPassed ? TEXT("PASS") : TEXT("FAIL"));
UE_LOG(LogTemp, Warning, TEXT("=== [TC-01] END ==="));
```

## 테스트 완료 후 정리

테스트 코드와 더미 데이터는 반드시 제거한다:
1. BeginPlay에 삽입한 호출 코드 제거
2. CSV 더미 행 (9900번대) 제거
3. 테스트 전용 함수는 `#if WITH_EDITOR` 가드 안에 남겨둘 수 있음
