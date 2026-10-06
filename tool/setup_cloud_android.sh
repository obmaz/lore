#!/usr/bin/env bash
# Linux 클라우드에서 Android release 빌드 도구를 작업 공간에 준비한다.
# 시스템 디렉터리를 바꾸지 않아 권한이 제한된 실행 환경에서도 다시 실행할 수 있다.
set -euo pipefail

repo_root=$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)
cloud_root=${COMMUNITY_CLOUD_ROOT:-"$(dirname "$repo_root")/shared"}
flutter_version=${COMMUNITY_FLUTTER_VERSION:-3.47.5}
sdk_tools_url=https://dl.google.com/android/repository/commandlinetools-linux-16111833_latest.zip
sdk_tools_sha256=0877a1d048fe4a24efe2eff536ca4223f7adeb58648bb81909d33c446918cfa8

die() { printf '오류: %s\n' "$*" >&2; exit 1; }
note() { printf '%s\n' "$*"; }
need() { command -v "$1" >/dev/null 2>&1 || die "필요한 명령이 없습니다: $1"; }

[[ $(uname -s) == Linux && $(uname -m) == x86_64 ]] || die 'Linux x86_64 환경에서만 지원합니다.'
for command_name in curl python3 tar unzip xz sha256sum; do need "$command_name"; done
mkdir -p "$cloud_root/downloads" "$cloud_root/gradle/init.d" "$cloud_root/android-user" "$cloud_root/pub-cache"
cloud_root=$(CDPATH= cd -- "$cloud_root" && pwd -P)
[[ -w $cloud_root ]] || die "쓰기 권한이 없습니다: $cloud_root"
[[ $cloud_root != *[[:space:]]* ]] || die '설치 경로에 공백을 넣지 마세요(Java 프록시 설정에 쓰입니다).'

download() {
  local url=$1 file=$2 checksum=$3
  if [[ -f $file ]] && printf '%s  %s\n' "$checksum" "$file" | sha256sum -c --status; then return; fi
  curl -fL --retry 3 --output "$file.part" "$url"
  printf '%s  %s\n' "$checksum" "$file.part" | sha256sum -c --status || die "SHA-256이 다릅니다: $url"
  mv "$file.part" "$file"
}

jdk_root="$cloud_root/jdk21"
if [[ ! -x $jdk_root/bin/javac ]] || [[ $($jdk_root/bin/javac -version 2>&1) != javac\ 21.* ]]; then
  note 'Temurin JDK 21 설치 중...'
  metadata="$cloud_root/downloads/temurin-jdk21.json"
  curl -fsSL 'https://api.adoptium.net/v3/assets/latest/21/hotspot?architecture=x64&image_type=jdk&os=linux&vendor=eclipse' -o "$metadata"
  mapfile -t package_info < <(python3 - "$metadata" <<'PY'
import json, sys
package = json.load(open(sys.argv[1]))[0]['binary']['package']
print(package['link'])
print(package['checksum'])
PY
  )
  jdk_archive="$cloud_root/downloads/temurin-jdk21.tar.gz"
  download "${package_info[0]}" "$jdk_archive" "${package_info[1]}"
  jdk_stage=$(mktemp -d "$cloud_root/jdk21.XXXXXX")
  tar -xf "$jdk_archive" -C "$jdk_stage" --strip-components=1
  [[ -x $jdk_stage/bin/javac ]] || die 'JDK 압축 파일에 javac가 없습니다.'
  if [[ -e $jdk_root ]]; then die "기존 JDK를 덮어쓰지 않습니다: $jdk_root"; fi
  mv "$jdk_stage" "$jdk_root"
fi

flutter_root="$cloud_root/flutter"
flutter_ok=false
if [[ -x $flutter_root/bin/flutter ]]; then
  installed_version=$($flutter_root/bin/flutter --version --machine | python3 -c 'import json,sys; print(json.load(sys.stdin)["frameworkVersion"])')
  [[ $installed_version == "$flutter_version" ]] && flutter_ok=true
fi
if [[ $flutter_ok == false ]]; then
  [[ ! -e $flutter_root ]] || die "기존 Flutter 버전이 다릅니다. 덮어쓰지 않습니다: $flutter_root"
  note "Flutter $flutter_version 설치 중..."
  releases="$cloud_root/downloads/flutter-releases-linux.json"
  curl -fsSL https://storage.googleapis.com/flutter_infra_release/releases/releases_linux.json -o "$releases"
  mapfile -t release_info < <(python3 - "$releases" "$flutter_version" <<'PY'
import json, sys
releases = json.load(open(sys.argv[1]))['releases']
item = next((r for r in releases if r['version'] == sys.argv[2] and r['channel'] == 'stable'), None)
if item is None:
    raise SystemExit('지정한 Flutter stable 버전이 없습니다.')
print(item['archive'])
print(item['sha256'])
PY
  )
  flutter_archive="$cloud_root/downloads/flutter-${flutter_version}.tar.xz"
  download "https://storage.googleapis.com/flutter_infra_release/releases/${release_info[0]}" "$flutter_archive" "${release_info[1]}"
  flutter_stage=$(mktemp -d "$cloud_root/flutter.XXXXXX")
  tar -xJf "$flutter_archive" -C "$flutter_stage"
  [[ -x $flutter_stage/flutter/bin/flutter ]] || die 'Flutter 압축 파일에 실행 파일이 없습니다.'
  mv "$flutter_stage/flutter" "$flutter_root"
  rmdir "$flutter_stage"
fi

sdk_root="$cloud_root/android-sdk"
sdkmanager="$sdk_root/cmdline-tools/latest/bin/sdkmanager"
if [[ ! -x $sdkmanager ]]; then
  note 'Android SDK 명령줄 도구 설치 중...'
  [[ ! -e $sdk_root/cmdline-tools/latest ]] || die "불완전한 Android 도구 설치를 덮어쓰지 않습니다: $sdk_root/cmdline-tools/latest"
  # 공식 고정 버전을 해시로 확인해 다른 환경에서도 같은 도구를 사용한다.
  tools_archive="$cloud_root/downloads/android-commandlinetools-16111833.zip"
  download "$sdk_tools_url" "$tools_archive" "$sdk_tools_sha256"
  tools_stage=$(mktemp -d "$cloud_root/android-tools.XXXXXX")
  unzip -q "$tools_archive" -d "$tools_stage"
  [[ -x $tools_stage/cmdline-tools/bin/sdkmanager ]] || die 'Android 도구 압축 파일이 올바르지 않습니다.'
  mkdir -p "$sdk_root/cmdline-tools"
  mv "$tools_stage/cmdline-tools" "$sdk_root/cmdline-tools/latest"
  rmdir "$tools_stage"
fi

proxy_ca=${COMMUNITY_PROXY_CA:-${CODEX_PROXY_CERT:-}}
if [[ -z $proxy_ca && -f /usr/local/share/ca-certificates/environment-proxy-ca.crt ]]; then
  proxy_ca=/usr/local/share/ca-certificates/environment-proxy-ca.crt
fi
java_options=${JAVA_TOOL_OPTIONS:-}
if [[ -n ${HTTPS_PROXY:-${https_proxy:-}} ]]; then
  mapfile -t proxy_parts < <(python3 - "${HTTPS_PROXY:-${https_proxy:-}}" <<'PY'
import sys, urllib.parse
url = urllib.parse.urlsplit(sys.argv[1])
if not url.hostname or url.username or url.password:
    raise SystemExit('Java가 사용할 프록시 주소에는 호스트만 있어야 합니다.')
print(url.hostname)
print(url.port or 8080)
PY
  )
  java_options+=" -Dhttps.proxyHost=${proxy_parts[0]} -Dhttps.proxyPort=${proxy_parts[1]}"
  java_options+=" -Dhttp.proxyHost=${proxy_parts[0]} -Dhttp.proxyPort=${proxy_parts[1]}"
fi
if [[ -n $proxy_ca ]]; then
  [[ -f $proxy_ca ]] || die "프록시 CA 파일이 없습니다: $proxy_ca"
  truststore="$cloud_root/proxy-cacerts"
  cp "$jdk_root/lib/security/cacerts" "$truststore"
  "$jdk_root/bin/keytool" -importcert -noprompt -alias community-cloud-proxy \
    -file "$proxy_ca" -keystore "$truststore" -storepass changeit >/dev/null
  java_options+=" -Djavax.net.ssl.trustStore=$truststore -Djavax.net.ssl.trustStorePassword=changeit"
fi

export JAVA_HOME="$jdk_root" ANDROID_HOME="$sdk_root" ANDROID_SDK_ROOT="$sdk_root"
export ANDROID_USER_HOME="$cloud_root/android-user" PUB_CACHE="$cloud_root/pub-cache"
export GRADLE_USER_HOME="$cloud_root/gradle" COMMUNITY_ANDROID_ROOT="$repo_root/android"
export PATH="$jdk_root/bin:$flutter_root/bin:$sdk_root/platform-tools:$PATH"
export JAVA_TOOL_OPTIONS="${java_options# }"

missing_packages=()
for package in 'platforms;android-35' 'platforms;android-36' 'build-tools;36.0.0' \
    'ndk;28.2.13676358' 'cmake;3.22.1' 'platform-tools'; do
  case $package in
    platforms\;*) package_dir="$sdk_root/platforms/${package#*;}" ;;
    build-tools\;*) package_dir="$sdk_root/build-tools/${package#*;}" ;;
    ndk\;*) package_dir="$sdk_root/ndk/${package#*;}" ;;
    cmake\;*) package_dir="$sdk_root/cmake/${package#*;}" ;;
    *) package_dir="$sdk_root/$package" ;;
  esac
  [[ -f $package_dir/source.properties ]] || missing_packages+=("$package")
done
if ((${#missing_packages[@]})); then
  note 'Android SDK 구성요소 설치 중...'
  "$sdkmanager" --sdk_root="$sdk_root" "${missing_packages[@]}"
fi

cp "$repo_root/tool/cloud_gradle_mirror.init.gradle" "$GRADLE_USER_HOME/init.d/community-maven-mirror.gradle"
env_file="$cloud_root/community-android.env"
{
  for var in JAVA_HOME ANDROID_HOME ANDROID_SDK_ROOT ANDROID_USER_HOME PUB_CACHE GRADLE_USER_HOME COMMUNITY_ANDROID_ROOT JAVA_TOOL_OPTIONS; do
    printf 'export %s=%q\n' "$var" "${!var}"
  done
  printf 'export PATH=%q:$PATH\n' "$jdk_root/bin:$flutter_root/bin:$sdk_root/platform-tools"
} > "$env_file"
chmod 600 "$env_file"

note "준비 완료. 다음 셸에서 사용: source '$env_file'"
note '빌드 번호는 Dropbox 최신 전달 기록을 확인한 뒤 지정하세요.'
