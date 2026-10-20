# Hoax Eliminator for Mac

은행이나 관공서 사이트에서 깔라고 했던 보안 프로그램을 찾아서 한 번에 정리하는 맥용 앱이에요.

윈도우용 [구라제거기](https://teus.me/hoaxeliminator/)에서 아이디어를 얻은 별도 프로그램이에요. 원작자(BLUEnLIVE)가 만든 공식 맥 버전이 아니에요.

## 할 수 있는 일

- 맥에 남아 있는 보안 프로그램을 찾아서 목록으로 보여 줘요.
- 프로그램마다 무엇이 남아 있는지 쉬운 말로 알려 줘요.
  - 앱, 자동 실행 설정, 브라우저 연결, 루트 인증서, 설치 기록
- 고른 프로그램을 한 번에 정리해요. 파일은 휴지통으로 옮겨요.
- 키체인에 남은 업체 루트 인증서와 설치 기록도 함께 지울 수 있어요.
- 회사 업무에 필요한 프로그램은 "업무용"으로 표시해서 남겨 둘 수 있어요.
- 목록에 없는 의심 항목도 찾아볼 수 있어요. 이 항목은 처음에 체크하지 않은 상태로 보여 줘요.

## 찾는 프로그램

| 프로그램 | 제작사 |
|---|---|
| AhnLab Safe Transaction (ASTx) | AhnLab |
| TouchEn nxKey | RaonSecure |
| INISAFE CrossWeb EX | INITECH |
| iniLINE CrossEX / CrossWarpEX | iniLINE |
| Veraport | Wizvera |
| Delfino | Wizvera |
| KeySharp Biz / NX Biz | RaonSecure |
| IPinside LWS Agent | Interezen |
| AnySign4PC | SoftForum (Hancom Secure) |
| nProtect Online Security | INCA Internet |
| MagicLine4NX | DreamSecurity |
| MarkAny MaSafeViewer / ePageSafer | MarkAny |
| SecuKit NXS | KICA |
| KSign CASE Agent | KSign |
| VestCert | Yettiesoft |
| XecureWeb\* | SoftForum |
| UniSign\* | CrossCert |

\* 맥용 설치 파일을 구하지 못해서, 찾는 경로를 확인하지 못했어요.

나머지 프로그램은 각 제작사가 배포하는 맥용 설치 파일을 설치하지 않고 풀어서, 어디에 무엇이 깔리는지 확인했어요.

## 윈도우판과 다른 점

윈도우의 구라제거기는 "프로그램 추가/제거" 목록에서 보안 프로그램을 찾아서, 제작사 제거 프로그램을 차례로 실행해요. 맥에는 그런 목록이 없어서, 설치하면서 남긴 흔적을 하나하나 직접 찾아요.

ActiveX나 키보드 보안 드라이버처럼 윈도우에만 있는 것은 맥에 없어요. 대신 맥에서는 로그인할 때마다 뒤에서 돌던 자동 실행 설정과, 키체인에 남는 루트 인증서가 중요해요. 루트 인증서는 제작사 제거 프로그램으로 지워도 남는 경우가 많아요.

## 안전하게 지워요

- **휴지통으로:** 파일은 바로 지우지 않고 휴지통으로 옮겨요. 잘못 지웠다면 휴지통에서 꺼내면 돼요.
- **손대지 않는 곳:** 공동인증서(NPKI) 폴더, 키체인의 다른 인증서, macOS 시스템 폴더는 건드리지 않아요.
- **같이 쓰는 폴더:** 여러 회사 프로그램이 같이 쓰는 폴더는 비어 있을 때만 정리해요.
- **미리 보여 드려요:** 관리자 암호가 필요한 작업은 실행하기 전에 무엇을 하는지 모두 보여 드려요. 암호 창에서 취소하면 아무것도 바뀌지 않아요.

은행 사이트에 다시 들어가면 보안 프로그램을 설치하라고 할 수 있어요. 그때 설치하고, 볼일을 마치면 다시 정리하면 돼요.

## 설치

1. [Releases](../../releases)에서 `Hoax-Eliminator-for-Mac-<버전>.zip`과 `.sha256` 파일을 받아요.
2. 체크섬을 확인해요. 터미널에서 다음을 실행해서 `OK`가 나오면 돼요.
   ```sh
   shasum -a 256 -c Hoax-Eliminator-for-Mac-*.zip.sha256
   ```
3. 압축을 풀고 `Hoax Eliminator for Mac.app`을 응용 프로그램 폴더로 옮겨요.

이 앱은 Apple 공증을 받지 않은 빌드라서, 처음 한 번은 macOS가 실행을 막아요.

1. 경고 창에서 [완료]를 눌러요.
2. 시스템 설정 > 개인정보 보호 및 보안에서 [그래도 열기]를 눌러요.
3. 앱을 다시 열고 [그래도 열기]를 누른 뒤 맥 로그인 암호를 입력해요.

macOS 13 이상에서 쓸 수 있고, Apple Silicon과 Intel 맥을 모두 지원해요.

## 직접 빌드하기

Xcode 명령줄 도구가 필요해요.

```sh
cd HoaxEliminatorForMac
./build.sh            # .build/Hoax Eliminator for Mac.app (이 맥의 아키텍처)
./build.sh test       # 자체 점검: 프로젝트 안의 가짜 파일 구조로 확인해요
./build.sh package    # ../dist/ 에 universal zip과 .sha256 생성
```

`./build.sh test --e2e`는 실제 `~/Library`에 테스트용 파일을 만들었다가 지우는 테스트예요. 자세한 내용은 `HoaxEliminatorForMac/Tests/E2E.swift`를 보세요.

## 출처

- 보안 프로그램 목록의 일부는 [hoax-eliminator-mac](https://github.com/wonmor/hoax-eliminator-mac)(MIT 라이선스)에서 출발했어요. 고지문은 `HoaxEliminatorForMac/Packaging/THIRD-PARTY-NOTICES.txt`에 있어요.
- 화면 구성과 이름은 윈도우용 구라제거기(BLUEnLIVE)에서 아이디어를 얻었어요.

## 라이선스

[MIT](LICENSE)
