"""
Gemini API 리뷰 스크립트
Usage: python gemini_review.py <review_type> <api_key> < input.txt
  review_type: plan | code
"""
import json, urllib.request, urllib.error, sys

def main():
    if len(sys.argv) < 3:
        print("Usage: python gemini_review.py <plan|code> <api_key>", file=sys.stderr)
        sys.exit(1)

    review_type = sys.argv[1]
    api_key = sys.argv[2]
    content = sys.stdin.read().strip()

    if not content:
        print("ERROR: stdin empty", file=sys.stderr)
        sys.exit(1)

    if review_type == "plan":
        prompt = (
            "이 UE5 C++ 구현 계획서를 검토해줘. "
            "빠진 부분, 리스크, 예외 케이스, 더 나은 설계 대안이 있으면 지적해줘. "
            "특히 GAS(Gameplay Ability System) 관점에서의 문제점도 확인해줘."
        )
    elif review_type == "code":
        prompt = (
            "이 UE5 C++ 코드를 20년차 시니어 개발자 관점에서 리뷰해줘. "
            "다음 관점을 모두 포함해서 검토해줘: "
            "1. 디자인 패턴 (SOLID, GoF 패턴 적용 적절성) "
            "2. 코드 가독성 (조합 메서드 패턴, API 일관성, 비즈니스/표현 레이어 분리) "
            "3. 메모리 관리 (UE5 GC 참조 규칙, 불필요한 복사) "
            "4. 엣지 케이스 (NULL 체크, 경계값, 비동기 타이밍) "
            "5. 성능 최적화 (TArray 재할당, 불필요한 루프) "
            "6. GAS 아키텍처 (ASC 소유권, GA 트리거 방식, 어트리뷰트 바인딩)"
        )
    else:
        prompt = "다음 내용을 리뷰해줘:"

    full_text = prompt + "\n\n" + content

    payload = json.dumps({
        "contents": [{
            "parts": [{
                "text": full_text
            }]
        }]
    })

    model = sys.argv[3] if len(sys.argv) > 3 else "gemini-2.5-flash"

    url = f"https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key={api_key}"

    req = urllib.request.Request(
        url,
        data=payload.encode("utf-8"),
        headers={"Content-Type": "application/json"},
        method="POST"
    )

    try:
        with urllib.request.urlopen(req) as resp:
            data = json.loads(resp.read().decode("utf-8"))
            text = data["candidates"][0]["content"]["parts"][0]["text"]
            print(text)
    except urllib.error.HTTPError as e:
        body = e.read().decode("utf-8")
        print(f"ERROR: Gemini API (HTTP {e.code})", file=sys.stderr)
        print(body, file=sys.stderr)
        sys.exit(1)
    except (KeyError, IndexError) as e:
        print(f"ERROR: Response parse failed - {e}", file=sys.stderr)
        sys.exit(1)
    except Exception as e:
        print(f"ERROR: {e}", file=sys.stderr)
        sys.exit(1)

if __name__ == "__main__":
    main()
