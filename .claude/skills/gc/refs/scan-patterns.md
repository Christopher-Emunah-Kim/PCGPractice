# scan-patterns
> gc [A] 스캔 단계 bash 명령 상세
> ON_DEMAND: /gc 실행 시 패턴별 grep 명령 참조

## P0 스캔 명령

### UE_LOG 잔존
```bash
grep -rn 'UE_LOG(' Source/RoastStaffGAS/ --include="*.cpp" --include="*.h"
```

### #if 0 블록
```bash
grep -rn '#if 0' Source/RoastStaffGAS/ --include="*.cpp" --include="*.h"
```

### TODO 주석 방치
```bash
grep -rn 'TODO:' Source/RoastStaffGAS/ --include="*.cpp" --include="*.h"
```

## P1 스캔 명령

### 하드코딩 매직 넘버
```bash
# 2~9999 범위 정수 리터럴 (0, 1, -1, 100.f 제외)
grep -rn '\b[2-9][0-9]\{0,3\}\b' Source/RoastStaffGAS/ --include="*.cpp" | grep -v '//.*'
```

### #include 과잉 (.h 15개 이상)
```bash
grep -rn '#include' Source/RoastStaffGAS/ --include="*.h" | awk -F: '{print $1}' | sort | uniq -c | sort -rn | awk '$1 >= 15'
```

## P2 스캔 명령

### 긴 함수 (100줄 이상) — 파일 단위 확인
```bash
awk '/\{/{depth++} /\}/{depth--; if(depth==0 && len>100) print FILENAME": "len" lines"; len=0} depth>0{len++}' \
  $(find Source/RoastStaffGAS -name "*.cpp")
```

## 자동 수정 가능 패턴 (승인 후)
| 패턴 | 자동 수정 | 방법 |
|------|----------|------|
| UE_LOG | ✅ | sed 치환 (KHS_* 매핑표 적용) |
| #if 0 | ✅ | 블록 전체 삭제 |
| 주석 코드 3줄+ | ✅ | 블록 삭제 |
| TODO 방치 | ❌ | 위치만 보고 |
| 하드코딩 | ❌ | 위치만 보고 (의미 불명) |
| include 과잉 | ⚠️ | 검토 후 수동 |
| 긴 함수 | ⚠️ | 검토 후 /coding 추출 |
