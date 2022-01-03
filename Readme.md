#install prow

##clone test-infra到本地
git clone https://github.com/kubernetes/test-infra.git

##准备hmac-token的secret

cd install

openssl rand -hex 20 > ./hmac-token

> 创建ns
kubectl create ns prow

kubectl create secret -n prow generic hmac-token --from-file=hmac=./hmac-token

##准备github-token，需要Github App的信息
App ID: 162160

> 从Github app下载private-key.pem到本地
private-key.pem

cd install

kubectl create secret -n prow generic github-token --from-file=cert=./private-key.pem --from-literal=appid=162160

##准备替换
The github app cert by replacing the <<insert-downloaded-cert-here>> string
The github app id by replacing the <<insert-the-app-id-here>> string
The hmac token by replacing the << insert-hmac-token-here >> string
The domain by replacing the << your-domain.com >> string 必须要替换成功
Optionally, you can update the cert-manager.io/cluster-issuer: annotation if you use cert-manager
Your github organization(s) by replacing the << your_github_org >> string

##准备image，替换成gcr.io的镜像，执行下面这个shell
cd install-prow

./load_images.sh

##测试minio本地docker运行，可以不用执行
docker run \
-d \
--name minio \
-p 9000:9000 \
-p 9001:9001 \
-e "MINIO_ROOT_USER=minioadmin" \
-e "MINIO_ROOT_PASSWORD=minioadmin" \
quay.io/minio/minio server /data --console-address ":9001"

##测试minio运行到k8s中，可以不用执行
cd install-prow

kubectl apply -f test-minio.yaml

##安装prowjob的crd

> 从你test-infra目录中copy prowjob的crd文件

cd install-prow

cp ~/app/test-infra/config/prow/cluster/prowjob_customresourcedefinition.yaml ./

kubectl apply --server-side=true -f prowjob_customresourcedefinition.yaml

##安装prow

cd install-prow

kubectl apply -f starter.yaml

##验证一下prow组件是否成功
kubectl get pods -n prow

> 在minio的console中创建tide的bucket

kubectl -n prow scale deploy tide --replicas=0

kubectl -n prow scale deploy tide --replicas=1

> 停止周期执行的echo-test

重新执行

kubectl apply -f starter.yaml

##安装Github app到repo中

install-prow Installed GitHub Apps

##暴露hook地址到公网
kubectl -n prow scale deploy hook --replicas=1

kubectl -n prow edit svc hook

把ClusterIP改为NodePort

kubectl -n prow get svc

ngrok http 32935

>得到公网地址

http://786f-2408-8456-3030-2f05-4946-7b5d-bd1c-4ed9.ngrok.io

之前的hmac-token填入github仓库的webhook的secret处
