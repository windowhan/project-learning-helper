---
name: learn-repo
description: 현재 열린 GitHub 레포를 DeepWiki로 수집·번역하고 Tutor 모드로 이해도를 높인다
triggers:
  - "learn-repo"
  - "learn repo"
argument-hint: ""
---

# learn-repo

## Purpose

레포를 Claude Code로 열고 `/learn-repo` 하나만 실행하면:
1. 현재 레포를 자동 감지
2. DeepWiki에 있으면 → 전체 페이지 수집 + 한국어 번역 저장
3. DeepWiki에 없으면 → 코드베이스 직접 분석
4. 번역본/분석본 기반으로 Tutor 모드 진입 (이해도 향상 Q&A)

## Workflow

아래 단계를 순서대로 실행하라.

---

### STEP 1: 현재 레포 감지

```bash
git remote get-url origin
```

- 결과에서 `owner`와 `repo` 추출
  - HTTPS: `https://github.com/{owner}/{repo}.git`
  - SSH: `git@github.com:{owner}/{repo}.git`
- `.git` suffix 제거
- 추출 실패 시: "git remote origin이 설정되지 않았습니다. GitHub 레포를 열고 실행해주세요." 출력 후 중단

---

### STEP 2: 이미 번역본 존재 여부 확인

`.omc/learner/{owner}-{repo}/_index.md` 파일이 존재하는지 확인한다.

- 존재하면 → **STEP 5 (Tutor 모드)** 로 바로 이동
- 없으면 → STEP 3 진행

---

### STEP 3: DeepWiki 접근 가능 여부 확인

`https://deepwiki.com/{owner}/{repo}` 를 WebFetch로 요청한다.

- 404, 접근 불가, "not found", "does not exist" 등이 응답에 포함되면:
  → "DeepWiki에 등록된 문서가 없습니다. 코드베이스를 직접 분석합니다." 출력
  → **STEP 4b (코드베이스 직접 분석)** 로 이동
- 정상 응답이면 → **STEP 4a (DeepWiki 수집)** 진행

---

### STEP 4a: DeepWiki 수집 + 번역

#### 4a-1. 페이지 목록 추출

메인 페이지(`https://deepwiki.com/{owner}/{repo}`) HTML에서 내부 링크를 추출한다.
- 패턴: `/{owner}/{repo}/` 로 시작하는 링크만 수집
- 중복 제거, 메인 페이지 자신도 목록에 포함

#### 4a-2. 각 페이지 수집 + 번역

페이지 목록을 순서대로 처리한다. 각 페이지마다:

1. WebFetch로 페이지 내용 수집
2. Agent tool로 번역 위임:
   ```
   subagent_type: "oh-my-claudecode:writer"
   model: "haiku"
   prompt: |
     다음 기술 문서를 한국어로 번역하세요.
     규칙:
     - 코드 블록 내용은 번역하지 말고 그대로 유지
     - URL, 파일 경로, 함수명, 변수명은 원문 유지
     - 기술 용어(API, SDK, CLI 등)는 영문 유지
     - 마크다운 형식(헤더, 리스트, 코드펜스 등) 유지
     - 자연스러운 한국어 기술 문서 문체 사용

     [원문]
     {페이지 내용}
   ```
3. 결과를 `.omc/learner/{owner}-{repo}/{순서}-{slug}.md` 로 저장

#### 4a-3. _index.md 생성

`.omc/learner/{owner}-{repo}/_index.md` 를 생성한다:

```markdown
# {owner}/{repo} 학습 자료

수집일: {오늘 날짜}
원본: https://deepwiki.com/{owner}/{repo}

## 페이지 목록

- [파일명]: [원본 URL]
- ...

## 읽기 순서

위 목록 순서대로 읽는 것을 권장합니다.
```

수집·번역 완료 후 → **STEP 5 (Tutor 모드)** 진행

---

### STEP 4b: 코드베이스 직접 분석 (DeepWiki 없을 때)

`explore` agent (model: haiku)를 사용해 코드베이스를 분석한다:

```
subagent_type: "oh-my-claudecode:explore"
prompt: |
  이 코드베이스의 구조를 분석하고 다음을 파악하라:
  1. 프로젝트 목적 및 주요 기능
  2. 핵심 디렉토리 및 파일 구조
  3. 주요 컴포넌트/모듈과 역할
  4. 데이터 흐름 및 핵심 알고리즘
  5. 외부 의존성 및 기술 스택
  결과를 한국어 마크다운으로 작성하라.
```

결과를 `.omc/learner/{owner}-{repo}/codebase-analysis.md` 로 저장.
`_index.md` 도 생성 (DeepWiki 없음 표시).

→ **STEP 5 (Tutor 모드)** 진행

---

### STEP 5: Tutor 모드

#### 준비

`.omc/learner/{owner}-{repo}/` 디렉토리의 모든 파일을 Read한다.

#### 소개 메시지 출력

```
📚 {owner}/{repo} 학습 튜터입니다.

저장된 문서를 읽었습니다. 이제 이 코드베이스에 대한 이해도를 높이기 위한
질문을 드리겠습니다. 모르는 건 모른다고 하셔도 괜찮아요.
답변 후 피드백과 함께 다음 질문으로 넘어갑니다.

준비되셨으면 시작하겠습니다!
```

#### 질문 진행 방식

문서 내용을 바탕으로 아래 순서로 질문한다. **한 번에 하나씩** 질문하고 사용자 답변을 받은 후 피드백과 함께 다음 질문으로 넘어간다.

**난이도 순서:**

1. **개요 파악** (쉬움)
   - "이 프로젝트는 어떤 문제를 해결하기 위한 것인가요?"
   - "주요 기능 3가지를 말해보세요."

2. **구조 이해** (보통)
   - "핵심 컴포넌트/모듈은 무엇이고 각각 어떤 역할을 하나요?"
   - "코드가 어떻게 구성되어 있나요? (디렉토리 구조 관점)"

3. **동작 원리** (보통)
   - "X 기능은 어떤 순서로 실행되나요?" (X는 핵심 기능으로 치환)
   - "데이터는 어떻게 흐르나요?"

4. **설계 의도** (어려움)
   - "왜 이런 아키텍처를 선택했을까요?"
   - "이 프로젝트에서 사용된 주요 디자인 패턴은 무엇인가요?"

5. **심화** (어려움)
   - 실제 코드 스니펫을 보여주며 "이 코드가 하는 일을 설명해보세요."
   - "이 프로젝트를 확장하거나 기여하려면 어디서부터 시작해야 할까요?"

#### 피드백 방식

각 답변 후:
- 잘 이해한 부분: 구체적으로 칭찬
- 보완할 부분: 문서의 어느 섹션을 다시 읽으면 좋을지 안내
- 핵심 포인트 보충: 놓친 중요 개념 짧게 보충
- 다음 질문으로 자연스럽게 전환

#### 종료

5단계 질문을 모두 마치거나 사용자가 "그만" / "종료" 를 입력하면:
- 전체 학습 요약 (잘 이해한 부분 / 더 공부하면 좋을 부분)
- 추천 다음 단계 제시

---

## Notes

- **번역 스킵**: `.omc/learner/{owner}-{repo}/` 가 이미 있으면 번역 과정 없이 바로 Tutor 모드 진입
- **재수집**: 강제로 다시 수집하려면 `.omc/learner/{owner}-{repo}/` 디렉토리를 삭제 후 재실행
- **비공개 레포**: DeepWiki는 공개 레포만 지원. 비공개 레포는 자동으로 코드베이스 직접 분석 모드로 동작
