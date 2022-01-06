# install prow

## clone test-infra到本地
git clone https://github.com/kubernetes/test-infra.git

## 准备hmac-token的secret

cd install

openssl rand -hex 20 > ./hmac-token

> 创建ns 和 hmac-token的secret

kubectl create ns prow


kubectl create secret -n prow generic hmac-token --from-file=hmac=./hmac-token


## 准备github-token，需要Github App的信息
App ID: 162160

> 从Github app下载private-key.pem到本地

private-key.pem

cd install

kubectl create secret -n prow generic github-token --from-file=cert=./private-key.pem --from-literal=appid=162160

## 准备替换
The github app cert by replacing the <<insert-downloaded-cert-here>> string(已通过命令执行)

The github app id by replacing the <<insert-the-app-id-here>> string(已通过命令执行)

The hmac token by replacing the << insert-hmac-token-here >> string(已通过命令执行)

The domain by replacing the << your-domain.com >> string 必须要替换成功

Optionally, you can update the cert-manager.io/cluster-issuer: annotation if you use cert-manager

Your github organization(s) by replacing the << your_github_org >> string (你的组织账户)

## 准备image，替换成gcr.io的镜像，执行下面这个shell，如果可以访问gcr.io就不需要执行
cd install-prow

./load_images.sh

## 测试minio本地docker运行，可以不用执行
docker run \
-d \
--name minio \
-p 9000:9000 \
-p 9001:9001 \
-e "MINIO_ROOT_USER=minioadmin" \
-e "MINIO_ROOT_PASSWORD=minioadmin" \
quay.io/minio/minio server /data --console-address ":9001"

## 测试minio运行到k8s中，可以不用执行
cd install-prow

kubectl apply -f test-minio.yaml

## 安装prowjob的crd

> 从你test-infra目录中copy prowjob的crd文件

cd install-prow

cp ~/app/test-infra/config/prow/cluster/prowjob_customresourcedefinition.yaml ./

kubectl apply --server-side=true -f prowjob_customresourcedefinition.yaml

## 安装prow

cd install-prow

kubectl apply -f starter.yaml


## 验证一下prow的各个组件是否成功
kubectl get pods -n prow

> 在minio的console中创建bucket: tide

kubectl -n prow scale deploy tide --replicas=0

kubectl -n prow scale deploy tide --replicas=1

> 在minio的console中创建bucket: statusreconciler

kubectl -n prow scale deploy statusreconciler --replicas=0

kubectl -n prow scale deploy statusreconciler --replicas=1

> 在minio的console中创建bucket: prow-logs

kubectl -n prow scale deploy crier --replicas=0

kubectl -n prow scale deploy crier --replicas=1

> 配置ghproxy

cd install-prow

cp ~/app/test-infra/config/prow/cluster/pushgateway_deployment.yaml ./

修改pushgateway_deployment.yaml中所有的namespace: default为prow

kubectl apply -f pushgateway_deployment.yaml

kubectl -n prow scale deploy ghproxy --replicas=0

kubectl -n prow scale deploy ghproxy --replicas=1

在starter.yaml中的ghproxy的deployment中添加下面的参数后，再次重启ghproxy

--legacy-disable-disk-cache-partitions-by-auth-header=false

> 停止周期执行的echo-test，注释掉
```yaml
    periodics:
    - interval: 1m
      agent: kubernetes
      name: echo-test
      spec:
        containers:
        - image: alpine
          command: ["/bin/date"]
```

重新执行

kubectl apply -f starter.yaml

## 安装Github app到repo中，在github页面上操作

在github->组织-> settings页面 -> installed Github Apps -> 操作你建立的github app -> Configure -> 选择仓库

## 配置prow的 hook组件

> 暴露hook、deck地址到公网

kubectl -n prow edit svc hook

kubectl -n prow edit svc deck

把ClusterIP改为NodePort

kubectl -n prow get svc

> 重启hook的命令

kubectl -n prow scale deploy hook --replicas=0

kubectl -n prow scale deploy hook --replicas=1

# 配置ngrok，端口号就是上面的svc的NodePort
```yaml
tunnels:
  deck:
    proto: http
    addr: 32395
  hook:
    proto: http
    addr: 31638
```
> 启动

ngrok start --all

## 得到hook的公网地址，作为某个仓库-webhooks中的callback url地址，注意添加path是 /hook

http://5216-2408-8456-3030-2f05-9c42-4c79-f8d7-9d1.ngrok.io/hook

把之前的hmac-token填入github仓库的webhook的secret处

cat hmac-token


## 配置prow的 deck组件 - 显示出PR status菜单

### 配置github oauth app

> 1.Create your GitHub Oauth application

oauth app：Authorization callback URL地址

http://d581-2408-8456-3030-2f05-9c42-4c79-f8d7-9d1.ngrok.io/github-login/redirect

>> 用得到oauth app的client id 和secret

vi github-oauth-config.yaml

client_id: 8616224f940863fbd513
client_secret: 12cf83ca6d2ac00a9725aa3ce35a4bbb3b674895
redirect_url: http://d581-2408-8456-3030-2f05-9c42-4c79-f8d7-9d1.ngrok.io/github-login/redirect
final_redirect_url: http://d581-2408-8456-3030-2f05-9c42-4c79-f8d7-9d1.ngrok.io/pr

> 2. 创建github-oauth-config的secret

kubectl -n prow create secret generic github-oauth-config --from-file=secret=./github-oauth-config.yaml


> 3. 创建cookie的secret

openssl rand -out cookie.txt -base64 32

kubectl -n prow create secret generic cookie --from-file=secret=./cookie.txt

> 4. 准备personal access token作为oauth-token

echo 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 > oauth-token

注意这里不是 =secret= 而是=oauth=

kubectl -n prow create secret generic oauth-token --from-file=oauth=./oauth-token

> 5. 修改starter.yaml的deck -> deployment部分

> 6. 重启deck

kubectl -n prow scale deploy deck --replicas=0

kubectl -n prow scale deploy deck --replicas=1


## 搞定带color的label

### 启动前编辑label_sync_job.yaml 和 label_sync_cron_job.yaml

cd install-prow

cp ~/app/test-infra/label_sync/cluster/label_sync_job.yaml ./

cp ~/app/test-infra/label_sync/cluster/label_sync_cron_job.yaml ./

cp ~/app/test-infra/label_sync/labels.yaml ./

### 通过labels.yaml创建 configMap: label-confg

kubectl -n prow create cm label-config --from-file=labels.yaml

kubectl apply -f label_sync_job.yaml

kubectl apply -f label_sync_cron_job.yaml



## 遇到的问题, hook, tide, crier组件添加代理，前提是你有梯子~~~
kubectl -n prow exec -it POD名字 sh

export http_proxy=http://192.168.110.235:1089

export https_proxy=http://192.168.110.235:1089

可以在容器内，查看git clone下来的repo信息，测试git clone

cd /tmp

git clone https://github.com/gitcpu-io/prow-demo.git

### 宿主机本本设置git代理（在terminal中执行git push时加快速度）
git config --global http.proxy http://192.168.110.235:1089
git config --global https.proxy http://192.168.110.235:1089

### 宿主机本本取消git代理
git config --global --unset http.proxy
git config --global --unset https.proxy
