---
name: sync-doc
version: 2.1.0
depends-on: []
suggests-next: ["/planning(코드→기획)", "/update-design(기획→코드)"]
allowed-tools: Read, Grep, Glob
---
# /sync-doc RUNBOOK
> 역할: 기획서 ↔ 코드베이스 불일치 탐지 + 보고

## STATE_MACHINE
```
INIT ──→ [A] 범위 확인
          └─ [B] 기획서 핵심 추출
                └─ [C] 코드 대조
                      └─ [D] 보고 + 후속 조치 제안 → DONE
```

## EXEC

### [A] 범위 확인
- 전체 / 특정 시스템 (사용자 확인)

### [B] 기획서 추출
`_Design/References/Systems/` 에서:
- DataTable 스키마 (컬럼/타입/FK)
- 함수/프로세스 흐름
- 예외처리 규칙
- ENUM 정의

### [C] 대조
```
| 항목          | 확인 내용                        |
|---------------|----------------------------------|
| 구조체 필드   | 기획서 컬럼 = 코드 구조체 필드   |
| FK 참조       | 기획서 FK = 코드 조회 방식       |
| ENUM 값       | 기획서 ENUM = 코드 ENUM          |
| 프로세스 흐름 | 기획서 순서 = 코드 실행 순서     |
| 예외처리      | 기획서 예외 = 코드 처리          |
```

### [D] 보고
```
## [SYNC] YYYY-MM-DD [시스템명]

🔴 코드 누락: | 항목 | 기획서 위치 | 설명 |
🟡 기획서 미반영: | 항목 | 코드 위치 | 설명 |
🔵 불일치: | 항목 | 기획서 | 코드 | 권장 |
✅ 일치: (요약)

후속:
A) 코드를 기획서에 맞춤 → /planning
B) 기획서를 코드에 맞춤 → /update-design
C) 현재 유지 (의도적 차이)
```

## RULES
```
- _Design/References/Systems/ 전체 순회 금지 (특정 시스템만)
- 불일치 발견 시 임의 수정 금지 (보고만)
- 후속 조치는 사용자 선택 후 /planning 또는 /update-design에 위임
```
