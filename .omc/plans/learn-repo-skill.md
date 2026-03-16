# learn-repo: DeepWiki 기반 코드베이스 학습 OMC Skill 계획

## 요구사항 요약

레포를 Claude Code로 열고 `/learn-repo` 하나만 실행하면:
1. 현재 레포의 git remote URL을 자동 감지한다
2. DeepWiki에 해당 레포가 있으면 → 전체 페이지 수집 + Deepseek 한국어 번역 → Tutor 모드
3. DeepWiki에 없으면 → 실제 코드베이스 직접 분석 → Tutor 모드
4. 이미 번역본이 저장돼 있으면 → 스크래핑 스킵, 바로 Tutor 모드

---

## 수용 기준 (Acceptance Criteria)

- [ ] `/learn-repo` 실행 시 `git remote get-url origin`으로 현재 레포 URL을 자동 감지한다
- [ ] `https://deepwiki.com/{owner}/{repo}` 접근 가능 여부를 확인한다
- [ ] DeepWiki 있음: 전체 페이지 수집 → Deepseek 번역 → `.omc/learner/{owner}-{repo}/` 저장 → Tutor 모드
- [ ] DeepWiki 없음: 코드베이스 직접 분석(explore agent) → Tutor 모드
- [ ] 번역본 이미 존재: 스크래핑 스킵, 바로 Tutor 모드 진입
- [ ] Tutor 모드: 레포 내용 기반 이해도 질문을 대화형으로 진행한다
- [ ] 번역은 Claude Haiku로 처리 (외부 API 키 불필요)

---

## 파일 구조

```
~/.claude/skills/learn-repo/
└── SKILL.md              # OMC 스킬 정의 (Claude에게 워크플로 지시)

# 데이터 저장 위치 (프로젝트별)
.omc/learner/{owner}-{repo}/
├── _index.md             # 페이지 목록 및 메타데이터
├── 00-overview.md        # 첫 번째 페이지 번역본
├── 01-architecture.md    # ...
└── ...
```

---

## 구현 단계

### 1단계: 번역 방식

`translate.py` 없음. 번역은 SKILL.md 워크플로 안에서 Claude Haiku로 직접 처리.

- 각 페이지 수집 후 `Task(subagent_type="oh-my-claudecode:writer", model="haiku")` 로 번역 위임
- 프롬프트: "다음 기술 문서를 한국어로 번역하세요. 코드 블록, URL, 기술 용어는 원문 유지."
- 외부 API 키 불필요, 별도 스크립트 없음

### 2단계: DeepWiki 페이지 탐색 로직

DeepWiki URL 패턴:
- 메인 페이지: `https://deepwiki.com/{owner}/{repo}`
- 하위 페이지: `https://deepwiki.com/{owner}/{repo}/{page-slug}`

페이지 탐색 방법:
1. 메인 페이지 WebFetch로 사이드바/목차에서 링크 추출
2. 각 링크를 순서대로 WebFetch
3. 내부 링크(`/owner/repo/...`)만 필터링

### 3단계: SKILL.md 워크플로 설계

**단일 진입점** (`/learn-repo`):
```
1. git remote get-url origin → owner/repo 추출
2. .omc/learner/{owner}-{repo}/ 존재 여부 확인
   → 이미 있으면: 바로 Tutor 모드로 점프

3. [없으면] DeepWiki 확인: https://deepwiki.com/{owner}/{repo} WebFetch
   → 404 or 접근 불가: "DeepWiki 없음" → 코드베이스 분석 모드
   → 접근 가능: Scrape 모드 진행

4. [Scrape 모드]
   a. 메인 페이지에서 내부 페이지 링크 추출
   b. 각 페이지 순서대로 WebFetch
   c. 각 페이지별 translate.py 실행 → 번역 저장
   d. _index.md 생성

5. [Tutor 모드] — Scrape 완료 후 또는 DeepWiki 없을 때
   a. 번역본 or 코드베이스 Read
   b. 이해도 질문 생성 (아키텍처 → 코드 흐름 → 개념 순)
   c. 사용자 답변 → 피드백 → 다음 질문 (점진적 난이도)
```

### 4단계: 스킬 등록

`~/.claude/skills/learn-repo/SKILL.md`를 작성하면 OMC가 자동 인식.
`/oh-my-claudecode:learn-repo` 또는 (단축) `/learn-repo` 로 호출 가능.

---

## 리스크 및 완화 방안

| 리스크 | 완화 방안 |
|--------|----------|
| DeepWiki 페이지 구조 변경 | WebFetch 결과에서 링크 패턴을 유연하게 파싱 |
| 번역 속도 | Haiku는 빠르지만 페이지 수가 많으면 병렬 처리 고려 |
| 번역 품질 | Haiku로 충분하나 복잡한 문서는 Sonnet으로 fallback 고려 |
| 대형 레포 (페이지 수십 개) | 진행 상황 표시, 이미 번역된 파일은 스킵 (incremental) |
| DeepWiki에 해당 레포 없음 | 404 감지 시 "DeepWiki에 등록되지 않은 레포입니다" 안내 |

---

## 검증 단계

1. 테스트 레포로 `https://github.com/anthropics/anthropic-sdk-python` 실행
2. `.omc/learner/` 에 번역 파일 생성 확인
3. 번역 품질 확인 (코드 블록 원문 유지, 기술 용어 처리)
4. Tutor 모드 실행 → 레포 내용 기반 질문 생성 확인

---

## 구현 순서 (우선순위)

1. `translate.py` 작성 및 Deepseek API 연동 테스트
2. `SKILL.md` 작성 (scrape 모드 워크플로)
3. 실제 레포로 end-to-end 테스트
4. Tutor 모드 워크플로 추가

---

## 관련 결정 사항

**번역에 Claude Haiku 선택 이유:** 외부 API 키 불필요, 별도 스크립트 없음, 빠르고 가벼움. Skill 내부에서 직접 위임 가능.

**OMC Skill 형태 선택 이유:** 범용성 (어떤 프로젝트에서든 호출 가능), Claude 네이티브 워크플로 활용.

**데이터 저장 위치:** `.omc/learner/` — OMC 표준 데이터 디렉토리 패턴 따름, git에 포함 가능.
