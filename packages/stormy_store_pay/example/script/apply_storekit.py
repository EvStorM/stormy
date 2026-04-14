#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import os
import sys

def apply_storekit_config():
    # 当前脚本存放于 temp/ 目录，所以我们需要回退到 example 根目录，再找 ios
    script_dir = os.path.dirname(os.path.abspath(__file__))
    example_dir = os.path.dirname(script_dir)
    scheme_path = os.path.join(example_dir, 'ios', 'Runner.xcodeproj', 'xcshareddata', 'xcschemes', 'Runner.xcscheme')

    if not os.path.exists(scheme_path):
        print(f"❌ 错误: 找不到目标文件 {scheme_path}")
        sys.exit(1)

    with open(scheme_path, 'r', encoding='utf-8') as f:
        content = f.read()

    # 检查是否已经注入过
    if '<StoreKitConfigurationFileReference' in content:
        print("✅ StoreKit 配置文件已处于关联状态，无需重复配置。")
        return

    # 准备要在 LaunchAction 末尾插入的节点 XML
    injection = '''
      <StoreKitConfigurationFileReference
         identifier = "../../Configuration.storekit">
      </StoreKitConfigurationFileReference>'''
    
    # 我们只对 LaunchAction（运行 Scheme）注入
    if '</LaunchAction>' in content:
        # 替换第一个找到的 </LaunchAction>（因为 Scheme 文件里通常只有一个标准的 LaunchAction）
        new_content = content.replace('</LaunchAction>', injection + '\n   </LaunchAction>', 1)
        
        with open(scheme_path, 'w', encoding='utf-8') as f:
            f.write(new_content)
        print(f"🎉 注入成功！已将 Configuration.storekit 绑定至 Runner Scheme。")
        print(f"👉 重新使用 flutter run 或在 Xcode 中运行即可直接使用该本地环境。")
    else:
        print("❌ 错误: 未能在 Scheme 中找到 <LaunchAction> 节点。")

if __name__ == "__main__":
    apply_storekit_config()
