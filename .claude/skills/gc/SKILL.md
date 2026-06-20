---
name: garbage-collection
version: 1.1.0
depends-on: []
suggests-next: ["COMMIT", "harness"]
allowed-tools: Read, Grep, Glob, Edit, Bash
---
# /gc RUNBOOK
> 역할: 프로젝트 전체 안티패턴 감지 → 자동 청소 → 보고
> 원칙: 코드 품질 저하 방지. 자동 수정 가능한 것만 자동 처리.

## STATE_MACHINE
```
INIT ──→ [A] 스캔 실행 (Source/ 전체)
          └─ [B] 결과 분류
                └─ [C] 사용자 보고 + 승인
                      ├─ A) 자동 수정 → [D] 청소 → [E] 보고
                      ├─ B) 항목 선택 → [D] → [E]
                      └─ C) 보고만 → DONE
```

## EXEC

### [A] 스캔 (Source/RoastStaffGAS/, .cpp/.h, Binaries/ 제외)
```
[P0] UE_LOG 잔존:    grep -rn 'UE_LOG(' Source/
[P0] #if 0 블록:     grep -rn '#if 0' Source/
[P0] TODO 방치:      grep -rn 'TODO:' Source/
[P1] 하드코딩:       매직 넘버 (2~9999 범위 리터럴, 0/-1/100.f 제외)
[P1] include 과잉:   .h 파일 #include 15개 이상
[P2] 긴 함수:        100줄 이상

→ 패턴별 상세 명령: ON_DEMAND_REFS scan-patterns 참조
```

### [B] 결과 분류
```
| 분류 | 패턴 | 건수 | 자동 수정 |
|------|------|------|-----------|
| P0 | UE_LOG 잔존 | N | ✅ |
| P0 | #if 0 블록 | N | ✅ |
| P0 | TODO 방치 | N | ❌ 위치만 보고 |
| P1 | 하드코딩 | N | ❌ 위치만 보고 |
| P1 | include 과잉 | N | ⚠️ 검토 필요 |
| P2 | 긴 함수 | N | ⚠️ 검토 필요 |
```

### [C] 사용자 보고
```
📌 [GC] | 스캔 결과 ([N]개 파일)

자동 수정 가능: UE_LOG N건 / #if 0 N건
수동 필요:      TODO N건 / 하드코딩 N건 (위치 목록 첨부)
검토 필요:      include과잉 N건 / 긴함수 N건 (파일 목록 첨부)

A) 자동 수정 가능 전체 정리
B) 항목별 선택
C) 보고만
```

### [D] 자동 청소 (A/B 선택 시)
```
순서:
1. UE_LOG → KHS_* 변환 (coding [C2] 동일 로직)
2. #if 0 블록 삭제
3. // 주석 처리 코드블록 삭제 (3줄+)

각 파일: Grep → Edit → 수정 로그 기록
```

### [E] 결과 보고
```
✅ [GC] DONE
| 패턴 | 처리 건수 | 영향 파일 |
수동 처리 목록: [위치 목록]
다음 권장: 커밋 → /harness (재발 방지)
```

## ON_DEMAND_REFS
```yaml
scan-patterns: .claude/skills/gc/refs/scan-patterns.md  # bash 명령 상세
```

## COMPLETION
```
DONE:        자동 청소 완료
DONE_REPORT: 보고만 (수동 처리 항목 있음)
CLEAN:       안티패턴 없음
```

## ABSOLUTE_RULES
```
1. 승인 없이 파일 수정 금지
2. Source/ 외 수정 금지
3. TODO 주석 자동 삭제 금지 (위치만 보고)
4. 하드코딩 자동 수정 금지 (의미 불명, 위치만 보고)
5. 전체 파일 재작성 금지
```
