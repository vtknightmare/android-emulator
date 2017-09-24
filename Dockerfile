# This dockerfile will build an image that can run a full android emulator + the visual emulator over VNC.
# This is maintained and intended to be run in AWS Docker instances with ECS support.
# Based on the work by https://github.com/ConSol/docker-headless-vnc-container

FROM ubuntu:17.04

MAINTAINER Aras Memisyazici
ENV REFRESHED_AT 2017-09-23

ENV JAVA_VERSION 8u92
ENV JAVA_HOME /usr/lib/jvm/java-$JAVA_VERSION

ENV DEBIAN_FRONTEND noninteractive
ENV DISPLAY :1
ENV NO_VNC_HOME /root/noVNC
ENV VNC_COL_DEPTH 24
ENV VNC_RESOLUTION 1280x1024
ENV VNC_PW student

ENV SAKULI_DOWNLOAD_URL https://labs.consol.de/sakuli/install

############### add linux-mint dependicies and update packages
#RUN apt-key adv --recv-key --keyserver keyserver.ubuntu.com "3EE67F3D0FF405B2"
RUN echo "deb http://packages.linuxmint.com/ rafaela main upstream import" >> /etc/apt/sources.list.d/mint.list \
    && echo "deb http://extra.linuxmint.com/ rafaela main " >> /etc/apt/sources.list.d/mint.list

############### xvnc / xfce installation \
RUN apt-get update && apt-get upgrade -y --allow-unauthenticated && apt-get install -y --allow-unauthenticated firefox supervisor unzip vim vnc4server wget xfce4

### Install noVNC - HTML5 based VNC viewer
RUN mkdir -p $NO_VNC_HOME/utils/websockify \
    && wget -qO- https://github.com/ConSol/noVNC/archive/consol_1.0.0.tar.gz | tar xz --strip 1 -C $NO_VNC_HOME \
    &&  wget -qO- https://github.com/kanaka/websockify/archive/v0.7.0.tar.gz | tar xz --strip 1 -C $NO_VNC_HOME/utils/websockify \
    && chmod +x -v /root/noVNC/utils/*.sh

####### Add Oracle JAVA JRE8 \
RUN mkdir -p $JAVA_HOME && wget -qO- $SAKULI_DOWNLOAD_URL/3rd-party/java/jre-$JAVA_VERSION-linux-x64.tar.gz | tar xz --strip 1 -C $JAVA_HOME && update-alternatives --install "/usr/bin/java" "java" "$JAVA_HOME/bin/java" 1 && update-alternatives --install "/usr/bin/javaws" "javaws" "$JAVA_HOME/bin/javaws" 1 && update-alternatives --install "/usr/lib/firefox/browser/plugins/mozilla-javaplugin.so" "mozilla-javaplugin.so" "$JAVA_HOME/lib/amd64/libnpjp2.so" 1

 ##### Install chrome browser \
RUN apt-get install -y --allow-unauthenticated \
	chromium-browser \
	chromium-browser-l10n \
	chromium-codecs-ffmpeg \
 && ln -s /usr/bin/chromium-browser /usr/bin/google-chrome \
 && echo "alias chromium-browser='/usr/bin/chromium-browser --user-data-dir'" >> /root/.bashrc \

 ########Setup specifics for android support - glx drivers etc. \
RUN apt-get install -y --allow-unauthenticated \
	git \
	lib32gcc1 \
	lib32ncurses5 \
	lib32stdc++6 \
	lib32z1 \
	libc6-i386 \
	libgl1-mesa-dev \
	nano \
 && apt-get clean

############Install Android SDK \
#RUN wget -qO - http://dl.google.com/android/android-sdk_r23.0.2-linux.tgz | tar xz -C /root/ --no-same-permissions \
# && chmod -R a+rX /root/android-sdk-linux \

RUN wget http://dl.google.com/android/android-sdk_r23.0.2-linux.tgz
RUN mkdir /root/android
RUN tar -C /root/android -xzvf ./android-sdk_r23.0.2-linux.tgz
ENV ANDROID_HOME /root/android/android-sdk-linux
ENV PATH $ANDROID_HOME/tools:$ANDROID_HOME/platform-tools:$PATH
RUN chmod -R 744 $ANDROID_HOME


###########Install Android tools \
RUN echo y | /root/android/android-sdk-linux/tools/android update sdk --filter tools --no-ui --force -a \
 && echo y | /root/android/android-sdk-linux/tools/android update sdk --filter platform-tools --no-ui --force -a \
 && echo y | /root/android/android-sdk-linux/tools/android update sdk --filter platform --no-ui --force -a \
 && echo y | /root/android/android-sdk-linux/tools/android update sdk --filter build-tools-21.0.1 --no-ui -a \
 && echo y | /root/android/android-sdk-linux/tools/android update sdk --filter sys-img-x86-android-18 --no-ui -a \
 && echo y | /root/android/android-sdk-linux/tools/android update sdk --filter sys-img-x86-android-19 --no-ui -a \
 && echo y | /root/android/android-sdk-linux/tools/android update sdk --filter sys-img-x86-android-21 --no-ui -a

#ENV ANDROID_HOME /root/android-sdk-linux


# xvnc server porst, if $DISPLAY=:1 port will be 5901
EXPOSE 5901
# novnc web port
EXPOSE 6901

ADD .vnc /root/.vnc
ADD .config /root/.config
ADD Desktop /root/Desktop
ADD scripts /root/scripts
RUN chmod +x /root/.vnc/xstartup /etc/X11/xinit/xinitrc /root/scripts/*.sh /root/Desktop/*.desktop

CMD ["/root/scripts/vnc_startup.sh", "--tail-log"]