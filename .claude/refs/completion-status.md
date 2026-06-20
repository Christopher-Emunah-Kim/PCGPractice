# COMPLETION STATUS
> 모든 Skill/Agent 공통 완료 상태 표준.

## 상태 정의
```
DONE              완료. 증거 제시.
DONE_WITH_CONCERNS 완료, 이슈 있음 (내용 명시).
BLOCKED           진행 불가. REASON/ATTEMPTED/NEXT 명시.
NEEDS_CONTEXT     정보 부족. 필요한 것 명시.
```

## BLOCKED 형식
```
STATUS: BLOCKED
REASON: [1-2 문장]
ATTEMPTED: [시도한 것]
NEXT: [사용자가 해야 할 것]
```

## 에스컬레이션
```
3회 동일 문제 반복 → BLOCKED 자동 선언 + "근본 구조 개선 필요" 명시
```
