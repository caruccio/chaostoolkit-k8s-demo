FROM centos:7

ENV LC_ALL en_US.utf8

RUN yum -y install https://centos7.iuscommunity.org/ius-release.rpm && \
    yum -y install python35u python35u-pip python35u-devel gcc && \
    yum clean all && \
    mkdir /chaostk

WORKDIR /chaostk

VOLUME /root/.kube

RUN python3.5 -m pip install -U pip && \
    python3.5 -m pip install -U chaostoolkit && \
    chaos discover chaostoolkit-kubernetes && \
    chmod 777 -R /chaostk

# Backward compat to k8s 1.9
RUN sed -i s/client.AppsV1beta1Api/client.ExtensionsV1beta1Api/ /usr/lib/python3.5/site-packages/chaosk8s/{actions,probes}.py
