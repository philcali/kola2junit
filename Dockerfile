FROM public.ecr.aws/amazonlinux/amazonlinux:2023

RUN yum install -y jq libxml2 bc

COPY junit5/platform-tests/src/test/resources/jenkins-junit.xsd /junit5/schema.xsd
COPY main.sh /usr/bin/kola2junit

WORKDIR /working

ENTRYPOINT [ "/usr/bin/kola2junit" ]
