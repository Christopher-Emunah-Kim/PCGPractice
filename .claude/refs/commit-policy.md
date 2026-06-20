# COMMIT POLICY
> 커밋 상세 규칙. /commit SKILL이 on_demand로 읽는다.

## 원칙
```yaml
타이밍: 모든 작업(CODE + TEST + 이슈수정) 완료 후 한 번에
        작업 중 커밋 제안 금지. "커밋해줘" 발언 시만 실행.

단위:   _Design/TODO.md MODULE 1개 = 커밋 1개
        "이 커밋만 되돌려도 나머지가 작동하는가"가 기준
        전체 변경사항을 MODULE 단위로 분할하여 순서대로 커밋

스테이징 한도: 스테이징 파일 수가 200개 이상이면 한 커밋당 150~200개만 스테이징
              초과 시 자동으로 N/총배치수 형태로 분할 커밋 (예: 1/4, 2/4...)
              git ls-files --others 또는 git diff --name-only로 전체 목록 추출 후 배치 처리
```

## 타입
```
feat(X):     새 기능 구현
fix(X):      버그/이슈 수정
refactor(X): 구조 개선 (동작 변화 없음)
data(X):     DataTable/CSV 변경
docs(X):     기획서/주석 갱신
rename(X):   파일/클래스/함수 이름 변경
remove(X):   파일/클래스/코드 삭제
```

## 메시지 형식
```
제목: 50자 이내
본문: 핵심 변경 bullet (선택)
footer: ref: PLAN_파일명
```

## 흐름
```
1. 사용자: "커밋해줘" 발언
2. Claude: _Design/Changesets/CHANGESET.md + _Design/TODO.md 읽기
           전체 변경파일을 MODULE별로 분류
3. Claude: 커밋 순서 + 각 커밋 메시지 + git 명령어 한꺼번에 제시
4. 사용자: 순서대로 실행
5. 사용자: 커밋 해시들 알려주면 CHANGESET + TODO 일괄 갱신
```

## 목표 git log 형태
```
abc1234 feat(Pierce-Core): BaseProjectile PIERCE 구현
def5678 data(Pierce-Data): DT_HitType_Param_Pierce 추가
ghi9012 feat(Pierce-GA): HandlePierceType 구현
jkl3456 fix(Pierce-Bug): SR 지적 PierceHitCount 오염 수정
→ 커밋 이력 = 작업 순서 문서
```

## CHANGESET 관리
```
세션 시작: status=PENDING_COMMIT 항목만 읽기 (COMMITTED 건너뜀)
compact:   COMMITTED 항목 5개 초과 시 제거 (Plans/completed/에 반영됨)
```
