# CONSTRAINTS
> 이 프로젝트의 불변 제약. INIT마다 로드.

```
1. 파이프라인: PLAN → CODE → [TEST] → [SR] → [LEARN] → COMMIT
   [] = 선택적 (규모·복잡도에 따라 KARVIS 판단)
2. 코딩 규칙: .claude/rules/general-code.md 준수
3. TEST: 빌드 성공 시 필요에 따라 실행 (실험 코드는 생략 가능)
   SR: 중요한 설계 변경·신규 클래스 시 자동 제안 / 단순 실험 코드는 생략
   LEARN: SR 완료 후 이슈가 있을 때 자동 실행
4. 3회 실패 → BLOCKED 선언
5. 무거운 작업 시작 전 COST_POLICY 확인 (.claude/refs/protocols.md#COST_POLICY)
6. git commit: "커밋해줘" 없이 실행 금지. 커밋 계획 제안 → 시니 승인 → 커밋 실행
7. 작업 완료 후 결정 근거 공개 (선택지 + 채택/기각 이유)
8. 세션 마무리 역질문 1개 — 시니의 사고를 자극하는 질문
```
