# 典の静态路由小助手

## 下载与安装

编译好的二进制文件可以在 [GitHub Releases](../../releases) 页面下载。

由于本项目未申请付费的 Apple 开发者证书，发布的应用采用 **Ad-hoc 方式签名**，**未经 Apple 公证**。在 macOS 上首次打开时，Gatekeeper 会阻止其运行。解压后，请在终端执行以下命令移除系统的隔离限制：

```bash
xattr -cr /path/to/Static\ Router.app
```

将 `/path/to/Static\ Router.app` 替换为应用的实际路径（例如 `~/Applications/Static\ Router.app`）。该命令会移除 macOS 在下载文件时自动添加的 `com.apple.quarantine` 隔离属性，之后即可正常启动应用。

## 应用说明

这是一个用Swift和SwiftUI写的macOS下的静态路由管理助手，可以方便地添加自己需要的路由，因为route命令需要超级用户权限，所以应用第一次运行的时候会需要输入密码。程序使用CoreData保存了用户添加的静态路由信息，再此后启动的时候就可以自动加载，避免重复输入。点击退出按钮可以安全退出应用，退出的时候会清空手动添加过的路由表，如果是意外退出，电脑重启后也会清空手动添加的路由表。

在工作状态下，状态图标为绿色，并且此时无法从列表中删除该路由，点击图标后会清除该路由在系统中的设置，此时会有一个按钮出现，可以用来从列表中删除该路由，从而下次启动的时候不会加载。

## 学到的一些知识点：

慢慢补充ing……



## TODO

- 重写SwiftUI，MVVM
- 使用Network Extension的方式添加路由（比较遥远，网上似乎没什么教程，而且要开通付费开发者账号……但这样的话iOS也可以使用了(V2)
- 想办法复用Views
- 添加汉语支持

License
-------

StaticRouteHelper 基于 [Apache License 2.0](./LICENSE) 协议开源。  
Copyright &copy; 2021, Derek Jing
