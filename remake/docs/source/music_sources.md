# 리메이크 음악 출처 확인

확인일: 2026-10-10. 음악 파일과 재생 로직은 변경하지 않았다.
원곡 식별은 사용 허락이나 라이선스 확인을 의미하지 않는다.

## 현재 사용 파일

`lib/services/audio_manager.dart`의 `BgmTrack`과 원본 계약 장부의 대응이다.
MP3 태그에는 인코더 정보만 있고 곡명·작곡가 정보는 없다.

| 사용 위치 | 파일 | DOS 대응 | 길이 | 원곡 식별 상태 |
| --- | --- | --- | --- | --- |
| 시작 | `music1_title.mp3` | `MUSIC1.BGM` | 65.04초 | 미확정 |
| 마을 | `music2_town.mp3` | `MUSIC2.BGM` | 154.15초 | 히사이시 조의 《바람계곡의 나우시카》 공통 테마 선율과 일치. 정확한 트랙/편곡은 미확정 |
| 필드 | `music3_ground.mp3` | `MUSIC3.BGM` | 87.12초 | 미확정 |
| 던전 | `music4_den.mp3` | `MUSIC4.BGM` | 92.16초 | 미확정 |
| 요새 | `music5_keep.mp3` | `MUSIC5.BGM` | 154.54초 | 미확정 |

## 마을 음악의 근거

원본 `ADLIB.PAS`의 `LoadSong`에 맞춰 ROL 형식인 `MUSIC2.BGM`의
음높이·음 길이를 읽었다. 채널 0의 첫 쉬는 음 이후 음높이는
`75,77,79,82,81,79,77,79,75,77,79,82,84,82,81,82,79`로 시작한다.

[Ichigo's의 Nausicaa 악보·MIDI 목록](https://ichigos.com/sheets/55)의
`Kaze no Densetsu`(風の伝説, 바람의 전설)와 `Tori no Hito`(鳥の人, 새의 사람)를
대조했다. 피아노 MIDI의 각 시작 시점에서 높은 음을 선택하고 66 미만을
제외한 뒤 옥타브를 제외한 음높이 열을 비교하면 각각 54개와 47개의
연속 음높이가 일치한다. 후자는 3반음 조옮김을 적용한 결과다.

이는 두 곡이 공유하는 나우시카 테마의 사용을 강하게 뒷받침하지만,
옥타브·반주·음 길이·전체 편곡의 동일성을 검증한 것은 아니다.
정확히 어느 트랙 제목에 해당하는지는 아직 확정하지 않는다.
MP3 직접 청취나 음원 인식 서비스가 확정한 결과도 아니다.

## 확인하지 못한 범위

- [원본 공개 소스](https://github.com/smgal/LoreTrilogy_1993)는 BGM을
  `MUSIC1`~`MUSIC5`로만 명명한다. `ADLIB.PAS` 작성자는 재생 드라이버의
  작성자이며, 이것만으로 음악 작곡가라고 할 수 없다.
- [당시 위키 문서 보존본](https://github.com/forkwikiman/enha/blob/master/mirror/%EB%98%90%EB%8B%A4%EB%A5%B8%20%EC%A7%80%EC%8B%9D%EC%9D%98%20%EC%84%B1%EC%A0%84.md)은
  일본 애니메이션 음악의 사용을 언급한다. 연결된
  [BGM 목록 글](https://blog.naver.com/masaruchi/110115693625)은 현재 비공개다.
- Modland의 Visual Composer 자료 177개와 Internet Archive의 Dr. Music
  ROL 1,762개를 대조했으나 같은 파일이나 확정 가능한 긴 선율 대응을
  찾지 못했다. 참고 음악은 게임 자산이나 저장소에 추가하지 않았다.
- 나머지 네 곡은 미확정이다. 짧은 음형이나 반복 반주만으로 곡명을 붙이지 않는다.

마을 MP3 SHA-256: `0104f05b423b06937de012f6d797dfc12978623badf7f271aef14155741f9a52`

DOS 파일 SHA-256: `6a9eacdbaabcc262c5de2f4948e6d7b7116716abaaaa86d270c22bfe66bbebce`
