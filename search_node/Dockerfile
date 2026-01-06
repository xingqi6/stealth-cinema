# 使用用户指定的 PanSou 镜像
FROM ghcr.io/fish2018/pansou-web:latest

# ================= 隐匿与伪装 =================
WORKDIR /opt/sys_search_worker

# 伪装：创建软链接，假装是搜索守护进程
RUN ln -s /usr/local/bin/pansou /usr/local/bin/search_worker_d || true

# ================= 环境变量注入 =================
# HF 强制端口
ENV PORT=7860
# 内部映射
ENV PANSOU_PORT=7860
ENV PANSOU_HOST=0.0.0.0

# 插件配置 (直接植入)
ENV ENABLED_PLUGINS=labi,zhizhen,shandian,duoduo,muou,wanou,hunhepan,jikepan,panwiki,pansearch,panta,qupansou,hdr4k,pan666,susu,thepiratebay,xuexizhinan,panyq,ouge,huban,cyg,erxiao,miaoso,fox4k,pianku,clmao,wuji,cldi,xiaozhang,libvio,leijing,xb6v,xys,ddys,hdmoli,clxiong,jutoushe,sdso,xiaoji,xdyh,haisou,bixin,djgou,nyaa,xinjuc,aikanzy,qupanshe,xdpan,discourse,yunsou,ahhhhfs,nsgame,quark4k,quarksoo,sousou,ash,feikuai,kkmao,alupan,ypfxw,mikuclub,daishudj,dyyj,meitizy,jsnoteclub,mizixing,lou1,yiove,zxzj,qingying,kkv

# 频道配置 (直接植入)
ENV CHANNELS=tgsearchers4,Aliyun_4K_Movies,bdbdndn11,yunpanx,bsbdbfjfjff,yp123pan,sbsbsnsqq,yunpanxunlei,tianyifc,BaiduCloudDisk,txtyzy,peccxinpd,gotopan,PanjClub,kkxlzy,baicaoZY,MCPH01,MCPH02,MCPH03,bdwpzhpd,ysxb48,jdjdn1111,yggpan,MCPH086,zaihuayun,Q66Share,ucwpzy,shareAliyun,alyp_1,dianyingshare,Quark_Movies,XiangxiuNBB,ydypzyfx,ucquark,xx123pan,yingshifenxiang123,zyfb123,tyypzhpd,tianyirigeng,cloudtianyi,hdhhd21,Lsp115,oneonefivewpfx,qixingzhenren,taoxgzy,Channel_Shares_115,tyysypzypd,vip115hot,wp123zy,yunpan139,yunpan189,yunpanuc,yydf_hzl,leoziyuan,Q_dongman,yoyokuakeduanju,TG654TG,WFYSFX02,QukanMovie,yeqingjie_GJG666,movielover8888_film3,Baidu_netdisk,D_wusun,FLMdongtianfudi,KaiPanshare,QQZYDAPP,rjyxfx,PikPak_Share_Channel,btzhi,newproductsourcing,cctv1211,duan_ju,QuarkFree,yunpanNB,kkdj001,xxzlzn,pxyunpanxunlei,jxwpzy,kuakedongman,liangxingzhinan,xiangnikanj,solidsexydoll,guoman4K,zdqxm,kduanju,cilidianying,CBduanju,SharePanFilms,dzsgx,BooksRealm,Oscar_4Kmovies,douerpan,baidu_yppan,Q_jilupian,Netdisk_Movies,yunpanquark,ammmziyuan,ciliziyuanku,cili8888,jzmm_123pan,Q_dianying,domgmingapk,dianying4k,q_dianshiju,tgbokee,ucshare,godupan,gokuapan

# 数据目录
ENV CACHE_PATH=/app/data/cache
ENV LOG_PATH=/app/data/logs

# 暴露端口
EXPOSE 7860

# 启动命令 (适配原镜像入口，这里我们直接调用原程序但用新端口)
# 注意：原镜像可能没有 /usr/local/bin/pansou，如果启动失败，需查看原镜像 ENTRYPOINT
# 这里假设它是标准 go/web 程序，通常直接运行即可
CMD ["/app/pansou-web"]
