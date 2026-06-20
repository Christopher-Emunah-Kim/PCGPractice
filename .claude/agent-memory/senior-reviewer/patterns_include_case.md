---
name: include 경로 대소문자 혼용
description: UI/Ingame vs UI/InGame — Windows는 통과, Linux 빌드 실패
type: feedback
---

프로젝트 폴더명: UI/InGame (대문자 G)
SlotContainerWidget.cpp는 기존 코드에서 "UI/Ingame/"(소문자 g)로 include하고 있음.
PassiveSlotWidget.h 추가 시 "UI/InGame/"(대문자 G)로 올바르게 추가 — 같은 파일에 혼용 발생.

**Why:** Windows NTFS는 대소문자 비민감이라 컴파일이 통과하지만, Linux/Mac 빌드 서버에서 실패.

**How to apply:** 새 include 추가 시 기존 같은 파일의 include 경로 대소문자를 통일. 프로젝트 기준: UI/InGame/ (대문자 G).
