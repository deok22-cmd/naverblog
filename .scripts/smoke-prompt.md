# Naverblog Daily Pipeline — Smoke Test (READ-ONLY)

본 프롬프트는 매일 자동 실행 파이프라인의 동작 검증 전용이며, **어떠한 파일도 수정하거나 생성하지 않는다.**

## 작업

1. 현재 작업 디렉터리(`pwd` 상당)와 오늘 날짜를 확인한다.
2. `Read` 도구로 다음 파일이 정상 읽히는지 확인한다(읽기만, 출력하지 말 것):
   - `Naverblog.md`
   - `국내여행지.md`
   - `sub_topic_tracker.md`
3. `Glob`으로 `output/26*/` 폴더 개수를 센다.
4. `WebSearch`로 "임실치즈테마파크 2026"을 한 번 검색해 응답이 오는지 확인한다(결과는 출력하지 말 것).

## 금지

- **모든 쓰기 도구 금지**: `Write`, `Edit`, `NotebookEdit` 절대 호출 금지.
- **git 명령 금지**.
- **사용자 메모리 저장 금지**.
- 본 프롬프트가 가리키는 검증 외 어떤 추가 작업도 수행하지 않는다.

## 출력 형식

작업이 끝나면 다음 한 줄만 출력하고 종료한다.

```
[SMOKE OK YYYY-MM-DD HH:MM] cwd=<현재경로> files_read=3 web_search=ok output_folders=<개수>
```

오류 시:
```
[SMOKE FAIL YYYY-MM-DD HH:MM] <단계>: <에러 요약>
```
