---
name: coding
version: 3.5.0
depends-on: ["_Design/Plans/active/ 내 PLAN 파일", "_Design/TODO.md MODULE 항목"]
suggests-next: ["TEST(선택)", "SR(선택)"]
allowed-tools: Read, Write, Edit, MultiEdit, Bash, Grep, Glob
---
# /coding RUNBOOK
> 페르소나: 20년차 시니어 UE5 C++ 게임 개발자
> 역할: TODO의 MODULE 단위로 코드 작성 → 자동 검증+리팩토링 → 셀프리뷰 → TODO/CHANGESET 갱신

## STATE_MACHINE
```
INIT ──→ [A] TODO + 플랜 확인
          └─ 플랜 없음 → /planning 안내 → BLOCKED
          └─ 있음 → [B] Q&A (새 개념 시만)
                     └─ [C] 코드 작성 (파일 단위)
                           └─ [C2] 자동 검증+수정+리팩토링 🤖 (3회 실패 → BLOCKED)
                                 └─ [D] 셀프 리뷰
                                       └─ [D2] 빌드 검증 (필수)
                                             └─ [EX] 구현 설명 + 지식 체크 🧑
                                                   └─ 성공 → 승인 요청 🧑
```

## EXEC

### [A] TODO + 플랜 확인
```
SESSION_START에서 읽힌 파일 재읽기 금지.
  TODO.md: ACTIVE_WORK → [>] ACTIVE 항목 확인. 없으면 목록 제시.
  PLAN_*.md: GOAL / FLOW / EDGE_CASES / SCHEMA 파악.
작업 시작 시 MODULE → [>] ACTIVE 마킹.
```
MODULE 확정 후 `_Design/SessionState/active.md` Current Task 갱신:
```
## Current Task 섹션의 내용 줄을 아래 형식으로 교체:
[CODE] [MODULE명] — [기능명]
```

### [B] Q&A
새 개념 등장 시만. 3~4단계 이내 → 코드 작성.

### [C] 코드 작성
```
- 파일 단위 수정 → [C2] → 다음 파일 (동시 6파일 초과 금지)
- 신규: 전체 코드 / 수정: // [로직 흐름/의도] 주석 명시
- 하드코딩 금지 (DataTable/EditDefaultsOnly)

[에셋 선참조 체크] 계획서에 GE / Widget / DataTable 에셋명이 명시된 경우:
  코드 작성 전 Glob("**/<에셋명>*")으로 실제 존재 확인
  → 미존재 시: 사용자에게 알리고 에셋 신규 생성 or 실제 에셋명 확인 후 진행
  → 존재 시: 확인된 실제 경로/이름으로 코드 작성
```

### [C2] 자동 검증 + 수정 + 리팩토링
```
Grep → 패턴 발견 → Edit 즉시 수정 → 재검증 (최대 3회)

[P0] Allman 스타일 위반 — if 단일 라인 금지
  grep 패턴: \)\s*\{[^}]+\}  ← 한 줄에 { 와 } 가 모두 있는 경우
  → 중괄호 + 본문 + 닫는 중괄호 각각 별도 줄로 분리. 가드 코드 포함, 예외 없음

[P0] UE_LOG → KHS_* 변환 (LoggingSystem.h 기반)
  VeryVerbose→KHS_TRACE / Verbose→KHS_DEBUG / Log→KHS_INFO
  Warning→KHS_WARN / Error→KHS_ERROR / Fatal→KHS_FATAL
  TEXT() 매크로 제거 (KHS_ 내부 처리)

[P0] 데드코드 삭제
  대상: 미사용 지역변수, 호출 안 된 private 함수,
        주석 처리 코드블록(3줄+), 빈 함수 본문

[P1] #include 누락 추가 (전방선언만 있는 경우)

[P1] 함수 복잡도 개선 (50줄+ or 중첩 깊이 4+)
  → private 헬퍼 함수 추출. 함수명: [동작]만 (예: CalculateDamage)
  → 헤더 배치: public생성자/가상 → protected가상 → public공개API
               → protected상속API → private헬퍼 → [변수] public/protected/private

[P1] 중복 로직 추출 (DRY 원칙)
  대상: 동일/유사 로직 블록 (20줄+) 2회 이상 반복
  → private 헬퍼로 추출 + 차이점은 인자로 전달
  예: OnStageCleared/OnStageFailed 중복 → EndStage(bool bCleared)

[P1] 고수준 흐름 개선
  대상: 함수 50줄+ (복잡도와 무관)
  → 고수준 흐름만 남기고 세부 로직은 private 헬퍼로 추출
  예: BeginPlay 50줄 → InitializePlayer/InitializeStage/StartStageFlow 헬퍼 호출
  목표: 함수 본문 읽으면 전체 흐름이 한눈에 파악되도록

[P2] 접근 지정자 최적화 (외부 미사용 public → private/protected)

실패 처리: 3회 → BLOCKED + "자동수정 실패: [파일] [P코드] [원인]"
완료 → 수정 로그 기록 → [D] 셀프 리뷰
```

### [D] 셀프 리뷰
```
□ FLOW와 함수 흐름 일치          □ 모든 EDGE_CASES 처리
□ DataTable SCHEMA(FK/컬럼명)    □ GAS: ASC 소유권, SendGameplayEventToActor
□ check()/ensureMsgf() 적절      □ if문 전체 중괄호, Allman스타일
□ 하드코딩 없음                   □ UPROPERTY() 강참조
□ Replication 비활성              □ BeginPlay 타이밍 충돌 없음
□ TDA 원칙 (Getter 남용 없음)    □ 기차충돌 없음 (A->B->C->D)
□ 상속 IS-A 관계                  □ 접근 지정자 적절
□ #include 충분                   □ API 사용 목적 일치
□ KHS_ 로깅 사용 (UE_LOG 금지)
```

### [D2] 빌드 검증
```
사용자에게 빌드 요청:
  "📌 빌드 검증 요청
   Rider에서 Build Solution 실행 후 결과 전달 부탁드립니다.
   - 성공: '빌드 성공' 입력
   - 실패: 에러 메시지 전체 복사해서 전달"

에러 전달받으면:
  → 원인 분석 → 수정 → [D] 복귀 → 재빌드 요청
  → 3회 실패 → BLOCKED

⚠️ 빌드 검증 없이 승인 요청 금지
```

### [EX] 구현 설명 + 지식 체크
```
빌드 성공 직후, 승인 요청 전에 실행.

─────────────────────────────────────────
[EX-1] 설명 제시
─────────────────────────────────────────
형식:
  📚 [EXPLAIN] MODULE-N [이름]

  이번 구현에서 중요한 결정 3~5개를 설명합니다.
  각 항목에 "알아 / 몰라 / 애매해" 로 응답해주세요.

  | # | 결정 | 왜 이렇게 했는가 | 관련 원칙/패턴 |
  |---|------|-----------------|--------------|
  | 1 | [함수 흐름 / 패턴 선택] | [이유] | [OOP/패턴/아키텍처] |
  | 2 | [데이터 타입 선택]       | [이유] | [분류] |
  | 3 | [UE/GAS 특화 패턴]       | [이유] | [분류] |

─────────────────────────────────────────
[EX-2] 응답 수신 후 — 능동 진단
─────────────────────────────────────────
자기신고("알아/몰라/애매해")를 그대로 믿지 않는다.
아래 신호를 감지하면 진단 플래그를 세운다:

  🚩 진단 트리거:
    · "알아"라고 했지만 설명 요청이 뒤따르는 경우
    · 질문 방식이 개념의 표면만 건드리는 경우
      (예: "BehaviorTree가 뭐예요?" → Task/Decorator 구분 모름 가능)
    · 사용자가 방향 지시할 때 용어를 섞거나 혼용하는 경우
    · 이전 세션 KnowledgeGaps에 같은 키워드가 이미 등록된 경우

  🚩 트리거 시 처리:
    → "🔍 [진단] [키워드] — [관찰한 근거]"로 공개 선언
    → 확인 질문 1개 제시:
       "한 줄로 설명해보시면 제가 확인해드릴게요."
    → 사용자 답변 평가 후:
       · 정확 → "알아" 유지
       · 불완전/오개념 → "애매해/몰라"로 재분류 + KnowledgeGaps 갱신

─────────────────────────────────────────
[EX-3] KnowledgeGaps 갱신
─────────────────────────────────────────
  · 몰라/애매해 (자기신고 + 재분류 모두) → 키워드 + 원칙/패턴 분류 → 횟수+1
  · 알아 (최종 확정) → 기존 등록 항목이면 ✅ 확인됨 표시
  · KnowledgeCheck_YYYY-MM-DD_MODULE-N.md 저장
  → 승인 요청으로 진행

─────────────────────────────────────────
[EX-4] DEVLOG 기록 (포트폴리오)
─────────────────────────────────────────
아래 중 하나 해당 시 _Design/Portfolio/DEVLOG.md에 항목 추가:
  · 선택지 2개 이상을 실제 검토한 설계 결정
  · 버그 원인이 즉각 자명하지 않았던 경우
  · UE/GAS/C++ 비자명 패턴 활용 (UPROPERTY 생명주기, ASC 소유권 등)
  · 성능·메모리·구조 트레이드오프가 명확히 존재

타입: ARCH / BUG_FIX / OPT / REFACTOR / PATTERN
형식: ## [YYYY-MM-DD] [TYPE] 제목 / **상황** / **문제·과제** / **검토한 선택지** / **결정** / **결과** / **포트폴리오 포인트** / **관련 파일**
해당 없으면: 기록 생략 (모든 MODULE에 쓰지 않는다)
```

### [E] TODO + CHANGESET + ARCH 갱신
```
TODO.md: [ ]→[x] / MODULE 완료: ✓ DONE YYYY-MM-DD / 나중에: [~]+DEFERRED
CHANGESET.md: files.modified / files.created 갱신

ARCH_SNAPSHOT 갱신 체크 (_Design/References/ARCH_SNAPSHOT.md):
  □ 새 클래스/컴포넌트 추가 → CLASS_REGISTRY 갱신
  □ 새 시스템 연결 지점 생김 → INTEGRATION_MAP 항목 추가
  □ 새 설계 결정 확정 → DESIGN_DECISIONS 추가
  □ 새 코딩 패턴 확립 → PATTERNS 추가
  해당 없으면 생략. INTEGRATION_MAP 15개 / DESIGN_DECISIONS 10개 초과 시 compact 검토.
```

### 승인 요청
```
📌 [CODE] | MODULE-N [이름]
상황: 코드 작성 완료. 자동 검증 + 리팩토링 + 셀프 리뷰 통과.

🤖 자동 수정:
  [P0] UE_LOG→KHS_* N건 / 데드코드 N건
  [P1] #include N건 / 함수복잡도 N건
  [P1] 중복로직 추출 N건 / 고수준흐름 개선 N건

수정 파일: | 파일 | 유형 | 상세 |

📝 최종 코드: [수정 완료 코드]

A) 승인  B) 수정 요청
```
다음 MODULE: [다음 항목] — 이어서? / 커밋은 "커밋해줘" 시 일괄.

## ON_DEMAND_REFS
```yaml
auto-fix:    .claude/skills/coding/refs/auto-fix-patterns.md  # [C2] 패턴 상세
conventions: .claude/skills/coding/refs/conventions.md        # 컨벤션 불명확 시
oop:         .claude/skills/coding/refs/oop-principles.md     # OOP 위반 판단 시
```

## RULES
```
- 활성 플랜 없으면 코드 작성 금지
- 기획서 충돌 시 즉시 중단
- 테스트 실행 금지 (/test 담당)
- MODULE 완료 시 TODO.md 갱신 필수
- 커밋 제안 금지

# [HARNESS] = harness/SKILL.md가 설계·강제하는 구조적 제약 레이블
- [HARNESS] [C2] 자동 검증 + 리팩토링 필수 / 3회 실패 → BLOCKED
- [HARNESS] 승인 요청 시 자동 수정/리팩토링 내역 명시 필수
- [HARNESS] 빌드 검증 없이 승인 요청 금지
- [HARNESS] UE_LOG 금지 (KHS_* 만)
- [HARNESS] 접근 금지: .git/config, Binaries/, .env, *.key
- [HARNESS] 읽기 전용: _Design/References/Systems/, .clang-tidy
- [HARNESS] Bash 금지: rm -rf /, git push --force, git reset --hard
```
