# auto-fix-patterns
> coding [C2] 자동 검증+수정 패턴 상세 예시
> ON_DEMAND: [C2] 단계에서 패턴 판단이 모호할 때 참조

## P0 — Allman 스타일 위반 (단일 라인 if)
```
감지 패턴: if(...) { ... } 가 한 줄에 { 와 } 가 모두 존재하는 경우
grep 패턴: \)\s*\{[^}]+\}

위반 예시 (금지):
  if (!HUD) { KHS_WARN("..."); return; }
  if (!Slot) { return; }

수정 후:
  if (!HUD)
  {
      KHS_WARN("...");
      return;
  }

적용 범위: 모든 if / else if / else 블록 — 예외 없음
중요: 가드 코드(early return) 도 동일하게 적용
```

## P0 — UE_LOG → KHS_* 변환 규칙
```
UE_LOG(LogTemp, VeryVerbose, TEXT("..."))  → KHS_INFO("...")   ← TRACE/DEBUG 금지
UE_LOG(LogTemp, Verbose, TEXT("..."))     → KHS_INFO("...")
UE_LOG(LogTemp, Log, TEXT("..."))         → KHS_INFO("...")
UE_LOG(LogTemp, Warning, TEXT("..."))     → KHS_WARN("...")
UE_LOG(LogTemp, Error, TEXT("..."))       → KHS_ERROR("...")
UE_LOG(LogTemp, Fatal, TEXT("..."))       → KHS_FATAL("...")

주의: TEXT() 매크로 제거 (KHS_* 내부에서 처리)
주의: 포맷 인자(%s, %d 등)는 그대로 유지
```

## P0 — KHS_DEBUG → KHS_INFO 변환
```
감지 패턴: KHS_DEBUG\(
이유: KHS_DEBUG는 에디터 로그 필터에서 표시되지 않아 디버깅 불가
→ 모든 KHS_DEBUG → KHS_INFO 으로 대체

grep 패턴: KHS_DEBUG\(
수정: KHS_DEBUG( → KHS_INFO(
```

## P0 — 서브시스템 매크로 강제
```
감지 패턴: GetWorld\(\)->GetSubsystem<  또는  GetGameInstance\(\)->GetSubsystem<
이유: 프로젝트 매크로(GET_WORLD_SUBSYSTEM / GET_GI_SUBSYSTEM)를 사용해야 일관성 유지

→ GetWorld()->GetSubsystem<T>()  →  GET_WORLD_SUBSYSTEM(T, VarName)
→ GetGameInstance()->GetSubsystem<T>()  →  GET_GI_SUBSYSTEM(T, VarName)

주의: 매크로 뒤 세미콜론 금지 (매크로 내부에 check() + 세미콜론 포함)
감지 패턴: GET_(WORLD|GI)_SUBSYSTEM\([^)]+\);
수정: 끝의 세미콜론 제거
```

## P0 — 데드코드 판별 기준
```
제거 대상:
  - 미사용 지역변수 (선언 후 읽기 없음)
  - 호출되지 않는 private 함수 (Grep으로 호출부 확인 후)
  - #if 0 블록 전체
  - 주석 처리된 코드 블록 3줄 이상
  - 빈 함수 본문 (순수 가상 아닌 경우)

제거 금지:
  - UFUNCTION(BlueprintCallable) — BP에서 호출 가능
  - UPROPERTY 접근자
  - 의도적 TODO 주석
```

## P1 — 함수 복잡도 기준
```
추출 대상:
  - 함수 50줄 이상 (복잡도 무관)
  - 중첩 깊이 4 이상

헬퍼 함수명 규칙:
  - [동작]만 명시 (예: CalculateDamage, InitializePool)
  - 부수효과 있으면 이름에 반영 (예: ApplyDamageAndNotify)
```

## P1 — 헤더 배치 순서
```
public:
  생성자 / 소멸자
  가상 함수 (UE 오버라이드)
  공개 API

protected:
  상속용 가상 함수
  상속용 비가상 함수

private:
  헬퍼 함수

변수:
  public UPROPERTY
  protected UPROPERTY
  private UPROPERTY / 일반 멤버
```
