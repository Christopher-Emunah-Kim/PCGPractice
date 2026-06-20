# KnowledgeCheck — 2026-04-17 CombatInfra MODULE-2

## 응답 요약

| # | 결정 | 자기신고 | 최종 |
|---|------|---------|------|
| 1 | EnemyAttributeSet→ApplyHitReact 책임 위임 (SRP/TDA) | 알아 | ✅ |
| 2 | CustomTimeDilation vs SetGlobalTimeDilation | 알아 | ✅ |
| 3 | MID 지연 초기화 캐싱 | 애매해 | 🟡 학습중 |

## 3번 상세 — UMaterialInstanceDynamic 캐싱

**오해**: 매번 새 UObject 생성해도 무방하다.

**실제**:
- `CreateAndSetMaterialInstanceDynamic(i)` = 새 UObject 힙 할당 + 메시 슬롯 교체 + 렌더 스테이트 무효화
- 렌더 스테이트 무효화 → GPU가 다음 프레임에 쉐이더 재빌드
- 이전 MID는 참조 해제 → GC 대상 → 피격 빈도 높을수록 GC 비용 누적
- 반면 `SetScalarParameterValue` = 파라미터 테이블 값만 업데이트, 슬롯 교체 없음

**핵심 구분**: "오브젝트 교체"는 비싸고, "값 변경"은 싸다.

**적용 패턴**: 최초 피격 시 `CachedMIDs.IsEmpty()` 체크 후 1회 생성 → 이후는 Set*만 반복.
