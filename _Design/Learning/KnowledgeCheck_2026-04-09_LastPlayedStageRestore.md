# KnowledgeCheck — 2026-04-09 | LastPlayedStageRestore

## 체크 항목

| # | 결정 | 응답 | 최종 분류 |
|---|------|------|-----------|
| 1 | SetLastPlayedStageID에서 SaveGame() 미호출 — 호출자 일괄 저장 | 알아 | ✅ 확인됨 |
| 2 | RestoreLastPlayedStage에서 OnNodeClicked 재사용 (DRY) | 알아 | ✅ 확인됨 |
| 3 | RestoreLastPlayedStage를 PopulateNodeMap() 이후에만 호출 — 호출 순서로 선행 조건 보장 | 몰라 | 📌 등록 |
| 4 | LastPlayedStageID 저장 시점 — 진입 확정 시 (UpdateStageRecord 아님) | 알아 | ✅ 확인됨 |

---

## KnowledgeGaps 신규 등록

### [GAP] 초기화 순서 의존 (Initialization Order Dependency)
- **키워드**: 선행 조건, 호출 순서, 타이밍 의존, 초기화 순서
- **원칙**: 함수 A의 완료 결과를 함수 B가 전제할 때, 코드 배치(순서)로 의존을 명시적으로 표현
- **왜 어려운가**: 순서 위반 시 컴파일 에러 없음 — 런타임 버그만 발생 (발견 어려움)
- **UE 등장 패턴**:
  - Widget: NativeOnInitialized(바인딩) → NativeConstruct(데이터) 순서
  - Subsystem: Collection.InitializeDependency로 의존 서브시스템 먼저 초기화
  - BeginPlay: 컴포넌트 초기화 → 로직 실행 순서
- **이번 사례**: PopulateNodeMap()(NodeDataCache 구축) → RestoreLastPlayedStage()(캐시 조회) 순서
- **횟수**: 1회
