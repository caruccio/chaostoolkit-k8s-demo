FROM centos:7

ENV LC_ALL en_US.utf8

RUN yum -y install https://centos7.iuscommunity.org/ius-release.rpm && \
    yum -y install python35u python35u-pip python35u-devel gcc git && \
    yum clean all && \
    mkdir /app

COPY chaostoolkit-documentation-code/tutorials/a-simple-walkthrough /app

WORKDIR /app

EXPOSE 8443/tcp
EXPOSE 8444/tcp

RUN python3.5 -m pip install -U pip && \
    python3.5 -m pip install -r requirements.txt && \
    chmod 777 -R /app
