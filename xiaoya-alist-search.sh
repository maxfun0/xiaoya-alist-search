#!/bin/bash

# 初始用户输入
echo "请输入小雅alist的docker名称 (默认: xiaoya):"
read -r DOCKER_NAME
DOCKER_NAME=${DOCKER_NAME:-xiaoya}

echo "请输入小雅alist的地址 (格式: http://192.168.0.254:5678):"
read -r AList_URL

echo "请输入新建docker的安装路径:"
read -r INSTALL_PATH

# 检查并创建目录
if [ ! -d "$INSTALL_PATH" ]; then
    mkdir -p "$INSTALL_PATH"
    echo "目录 $INSTALL_PATH 已创建。"
else
    echo "目录 $INSTALL_PATH 已存在。"
fi

while true; do
    echo "请输入新建docker的名称:"
    read -r NEW_DOCKER_NAME

    # 检查是否有同名的docker
    if [ "$(docker ps -a --filter "name=^/${NEW_DOCKER_NAME}$" --format '{{.Names}}')" ]; then
        echo "Error: Docker名称已存在，请重新输入。"
    else
        break
    fi
done

echo "请输入需要使用的端口:"
read -r PORT

# 计算新端口
NEW_PORT=$((PORT + 1))

echo "选择使用webdav或者alist套娃小雅alist:"
echo "如果你想分享多人使用，有公网ip，上行宽带至少有30-50兆，可以使用webdav。"
echo "如果你使用设备不多，没有公网ip，选择alist。"
echo "输入1选择webdav，输入2选择alist (默认: 1):"
read -r SERVICE_TYPE
SERVICE_TYPE=${SERVICE_TYPE:-1}

# 根据选择的服务类型进行不同的配置
if [ "$SERVICE_TYPE" -eq 1 ]; then
    echo "小雅alist是否开启强制登入? (1: 未开启, 2: 开启, 默认: 1):"
    read -r FORCE_LOGIN
    FORCE_LOGIN=${FORCE_LOGIN:-1}

    if [ "$FORCE_LOGIN" -eq 2 ]; then
        echo "请输入密码:"
        read -r PASSWORD
    else
        PASSWORD="guest"
    fi
else
    # 对于选择 AList 的情况，密码设置固定
    FORCE_LOGIN=1
    PASSWORD=""
fi

# 创建docker-compose文件并启动容器
COMPOSE_FILE=$(mktemp)
cat <<EOF > "$COMPOSE_FILE"
version: '3.3'
services:
    alist:
        image: 'xhofe/alist:v3.39.1'
        container_name: $NEW_DOCKER_NAME
        volumes:
            - '$INSTALL_PATH:/opt/alist/data'
        ports:
            - '$PORT:5244'
            - '$NEW_PORT:5245'
        environment:
            - PUID=0
            - PGID=0
            - UMASK=022
        restart: unless-stopped
EOF

docker-compose -f "$COMPOSE_FILE" up -d

# 等待容器启动
sleep 15

# 获取token信息（仅在选择 AList 时需要）
if [ "$SERVICE_TYPE" -eq 2 ]; then
    TOKEN=$(docker exec -i "$DOCKER_NAME" sqlite3 data/data.db <<EOF
select value from x_setting_items where key = 'token';
EOF
)
    echo "获取到的token: $TOKEN"
fi

# 停止容器
docker stop "$NEW_DOCKER_NAME"

# 等待容器停止
sleep 5

if [ ! -f "$INSTALL_PATH/data.db" ]; then
    docker start "$NEW_DOCKER_NAME"
    sleep 60
    docker stop "$NEW_DOCKER_NAME"
fi

# 备份数据库
mkdir -p "$INSTALL_PATH/alist-temp"
cp "$INSTALL_PATH/data.db" "$INSTALL_PATH/alist-temp/data.db.bak"

# 提取txt文件
docker cp "${DOCKER_NAME}:/index/." "$INSTALL_PATH/alist-temp/"

# 数据库操作
PYTHON_SCRIPT=$(cat <<EOF
import sqlite3
import json
import datetime
import logging
import os

# 配置日志输出格式
logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')

DB_FILE = "$INSTALL_PATH/data.db"  # 确保在 Bash 脚本中替换为实际路径
TXT_FOLDER = "$INSTALL_PATH/alist-temp"  # 指定处理的 TXT 文件夹
SEQ_INSERT = "INSERT OR REPLACE INTO sqlite_sequence (name, seq) VALUES ('x_storages', 19);"
BATCH_SIZE = 1000  # 批量插入大小

def insert_data(service_type, token, address, password, force_login):
    logging.info("Connecting to database...")
    conn = sqlite3.connect(DB_FILE)
    cursor = conn.cursor()

    # 执行序列插入
    logging.info("Inserting sequence...")
    cursor.execute(SEQ_INSERT)

    # 定义数据插入函数
    if service_type == 1:
        if force_login == 1:  # 未开启强制登陆
            username = "guest"
            password_input = "guest_Api789"
        else:
            username = "dav"
            password_input = password

        data = [
            (1, '/体育', 1, 'WebDav', 30, 'work', {"vendor":"other","address":address,"username":username,"password":password_input,"root_folder_path":"/dav/体育","tls_insecure_skip_verify":False}),
            (2, '/动漫', 2, 'WebDav', 30, 'work', {"vendor":"other","address":address,"username":username,"password":password_input,"root_folder_path":"/dav/动漫","tls_insecure_skip_verify":False}),
            (3, '/教育', 3, 'WebDav', 30, 'work', {"vendor":"other","address":address,"username":username,"password":password_input,"root_folder_path":"/dav/教育","tls_insecure_skip_verify":False}),
            (4, '/整理中', 4, 'WebDav', 30, 'work', {"vendor":"other","address":address,"username":username,"password":password_input,"root_folder_path":"/dav/整理中","tls_insecure_skip_verify":False}),
            (5, '/曲艺', 5, 'WebDav', 30, 'work', {"vendor":"other","address":address,"username":username,"password":password_input,"root_folder_path":"/dav/曲艺","tls_insecure_skip_verify":False}),
            (6, '/有声书', 6, 'WebDav', 30, 'work', {"vendor":"other","address":address,"username":username,"password":password_input,"root_folder_path":"/dav/有声书","tls_insecure_skip_verify":False}),
            (7, '/每日更新', 7, 'WebDav', 30, 'work', {"vendor":"other","address":address,"username":username,"password":password_input,"root_folder_path":"/dav/每日更新","tls_insecure_skip_verify":False}),
            (8, '/游戏', 8, 'WebDav', 30, 'work', {"vendor":"other","address":address,"username":username,"password":password_input,"root_folder_path":"/dav/游戏","tls_insecure_skip_verify":False}),
            (9, '/电子书', 9, 'WebDav', 30, 'work', {"vendor":"other","address":address,"username":username,"password":password_input,"root_folder_path":"/dav/电子书","tls_insecure_skip_verify":False}),
            (10, '/电影', 10, 'WebDav', 30, 'work', {"vendor":"other","address":address,"username":username,"password":password_input,"root_folder_path":"/dav/电影","tls_insecure_skip_verify":False}),
            (11, '/电视剧', 11, 'WebDav', 30, 'work', {"vendor":"other","address":address,"username":username,"password":password_input,"root_folder_path":"/dav/电视剧","tls_insecure_skip_verify":False}),
            (12, '/纪录片', 12, 'WebDav', 30, 'work', {"vendor":"other","address":address,"username":username,"password":password_input,"root_folder_path":"/dav/纪录片","tls_insecure_skip_verify":False}),
            (13, '/综艺', 13, 'WebDav', 30, 'work', {"vendor":"other","address":address,"username":username,"password":password_input,"root_folder_path":"/dav/综艺","tls_insecure_skip_verify":False}),
            (14, '/资料', 14, 'WebDav', 30, 'work', {"vendor":"other","address":address,"username":username,"password":password_input,"root_folder_path":"/dav/资料","tls_insecure_skip_verify":False}),
            (15, '/音乐', 15, 'WebDav', 30, 'work', {"vendor":"other","address":address,"username":username,"password":password_input,"root_folder_path":"/dav/音乐","tls_insecure_skip_verify":False}),
            (16, '/我的夸克分享', 16, 'WebDav', 30, 'work', {"vendor":"other","address":address,"username":username,"password":password_input,"root_folder_path":"/dav/我的夸克分享","tls_insecure_skip_verify":False}),
            (17, '/️我的115分享', 17, 'WebDav', 30, 'work', {"vendor":"other","address":address,"username":username,"password":password_input,"root_folder_path":"/dav/️我的115分享","tls_insecure_skip_verify":False}),
            (18, '/画质演示测试（4K，8K，HDR，Dolby）', 18, 'WebDav', 30, 'work', {"vendor":"other","address":address,"username":username,"password":password_input,"root_folder_path":"/dav/画质演示测试（4K，8K，HDR，Dolby）","tls_insecure_skip_verify":False}),
            (19, '/️我的PikPak分享', 19, 'WebDav', 30, 'work', {"vendor":"other","address":address,"username":username,"password":password_input,"root_folder_path":"/dav/️我的PikPak分享","tls_insecure_skip_verify":False})
        ]
    elif service_type == 2:
        data = [
            (1, '/体育', 1, 'AList V3', 30, 'work', {"root_folder_path":"/体育","url":address,"meta_password":"","username":"","password":"","token":token,"pass_ua_to_upsteam":True}),
            (2, '/动漫', 2, 'AList V3', 30, 'work', {"root_folder_path":"/动漫","url":address,"meta_password":"","username":"","password":"","token":token,"pass_ua_to_upsteam":True}),
            (3, '/教育', 3, 'AList V3', 30, 'work', {"root_folder_path":"/教育","url":address,"meta_password":"","username":"","password":"","token":token,"pass_ua_to_upsteam":True}),
            (4, '/整理中', 4, 'AList V3', 30, 'work', {"root_folder_path":"/整理中","url":address,"meta_password":"","username":"","password":"","token":token,"pass_ua_to_upsteam":False}),
            (5, '/曲艺', 5, 'AList V3', 30, 'work', {"root_folder_path":"/曲艺","url":address,"meta_password":"","username":"","password":"","token":token,"pass_ua_to_upsteam":True}),
            (6, '/有声书', 6, 'AList V3', 30, 'work', {"root_folder_path":"/有声书","url":address,"meta_password":"","username":"","password":"","token":token,"pass_ua_to_upsteam":True}),
            (7, '/每日更新', 7, 'AList V3', 30, 'work', {"root_folder_path":"/每日更新","url":address,"meta_password":"","username":"","password":"","token":token,"pass_ua_to_upsteam":True}),
            (8, '/游戏', 8, 'AList V3', 30, 'work', {"root_folder_path":"/游戏","url":address,"meta_password":"","username":"","password":"","token":token,"pass_ua_to_upsteam":True}),
            (9, '/电子书', 9, 'AList V3', 30, 'work', {"root_folder_path":"/电子书","url":address,"meta_password":"","username":"","password":"","token":token,"pass_ua_to_upsteam":True}),
            (10, '/电影', 10, 'AList V3', 30, 'work', {"root_folder_path":"/电影","url":address,"meta_password":"","username":"","password":"","token":token,"pass_ua_to_upsteam":True}),
            (11, '/电视剧', 11, 'AList V3', 30, 'work', {"root_folder_path":"/电视剧","url":address,"meta_password":"","username":"","password":"","token":token,"pass_ua_to_upsteam":True}),
            (12, '/纪录片', 12, 'AList V3', 30, 'work', {"root_folder_path":"/纪录片","url":address,"meta_password":"","username":"","password":"","token":token,"pass_ua_to_upsteam":True}),
            (13, '/综艺', 13, 'AList V3', 30, 'work', {"root_folder_path":"/综艺","url":address,"meta_password":"","username":"","password":"","token":token,"pass_ua_to_upsteam":True}),
            (14, '/资料', 14, 'AList V3', 30, 'work', {"root_folder_path":"/资料","url":address,"meta_password":"","username":"","password":"","token":token,"pass_ua_to_upsteam":True}),
            (15, '/音乐', 15, 'AList V3', 30, 'work', {"root_folder_path":"/音乐","url":address,"meta_password":"","username":"","password":"","token":token,"pass_ua_to_upsteam":True}),
            (16, '/我的夸克分享', 16, 'AList V3', 30, 'work', {"root_folder_path":"/我的夸克分享","url":address,"meta_password":"","username":"","password":"","token":token,"pass_ua_to_upsteam":True}),
            (17, '/️我的115分享', 17, 'AList V3', 30, 'work', {"root_folder_path":"/️我的115分享","url":address,"meta_password":"","username":"","password":"","token":token,"pass_ua_to_upsteam":True}),
            (18, '/画质演示测试（4K，8K，HDR，Dolby）', 18, 'AList V3', 30, 'work', {"root_folder_path":"/画质演示测试（4K，8K，HDR，Dolby）","url":address,"meta_password":"","username":"","password":"","token":token,"pass_ua_to_upsteam":True}),
            (19, '/️我的PikPak分享', 19, 'AList V3', 30, 'work', {"root_folder_path":"/️我的PikPak分享","url":address,"meta_password":"","username":"","password":"","token":token,"pass_ua_to_upsteam":True})
        ]

    current_time = datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    
    # 插入每条数据记录
    for entry in data:
        id, mount_path, order, driver, cache_expiration, status, addition = entry
        addition_json = json.dumps(addition).replace('"', '""')
        webdav_policy = 'native_proxy' if driver == 'WebDav' else '302_redirect'

        logging.info(f"插入挂载路径的数据: {mount_path}")

        # 执行插入语句
        cursor.execute(f"""
            INSERT INTO x_storages (id, mount_path, [order], driver, cache_expiration, status,
            addition, remark, modified, disabled, enable_sign, order_by, order_direction,
            extract_folder, web_proxy, webdav_policy, proxy_range, down_proxy_url)
            VALUES ({id}, '{mount_path}', {order}, '{driver}', {cache_expiration}, '{status}', "{addition_json}", '', 
            '{current_time}', 0, 0, 'name', 'asc', 'front', 0, '{webdav_policy}', 0, '')
        """)

    # 提交更改并关闭连接
    conn.commit()
    logging.info("数据插入成功且更改已提交.")
    conn.close()

def clear_table():
    """清空 x_search_nodes 表"""
    with sqlite3.connect(DB_FILE) as conn:
        cursor = conn.cursor()
        cursor.execute('DELETE FROM x_search_nodes')
        conn.commit()
        logging.info("x_search_nodes 表已清空。")

def create_table():
    """创建 x_search_nodes 表"""
    logging.info("创建数据库表 x_search_nodes.")
    with sqlite3.connect(DB_FILE) as conn:
        cursor = conn.cursor()
        cursor.execute('''
        CREATE TABLE IF NOT EXISTS x_search_nodes (
            parent TEXT,
            name TEXT,
            is_dir NUMERIC,
            size INTEGER
        )
        ''')
        conn.commit()

def check_and_create_index():
    """检查索引并创建索引"""
    with sqlite3.connect(DB_FILE) as conn:
        cursor = conn.cursor()
        cursor.execute("CREATE INDEX IF NOT EXISTS idx_x_search_nodes_parent ON x_search_nodes (parent, name)")
        conn.commit()
        logging.info("检查并确保索引 idx_x_search_nodes_parent 存在。")

def insert_data_batch(data_batch):
    """批量插入数据到 x_search_nodes 表"""
    with sqlite3.connect(DB_FILE) as conn:
        cursor = conn.cursor()
        cursor.executemany('''
        INSERT INTO x_search_nodes (parent, name, is_dir, size)
        VALUES (?, ?, ?, ?)
        ''', data_batch)
        conn.commit()

def process_file(file_path):
    """处理单个 TXT 文件并提取数据"""
    data_batch = []
    logging.info(f"开始处理文件: {file_path}")
    
    try:
        with open(file_path, 'r', encoding='utf-8') as file:
            for line in file:
                line = line.strip()
                if '#' in line:
                    parts = line.split('#')
                    path_with_file = parts[0].replace('./', '')
                else:
                    path_with_file = line.replace('./', '')

                last_slash_index = path_with_file.rfind('/')

                if last_slash_index != -1:
                    parent = '/' + path_with_file[:last_slash_index]
                    name = path_with_file[last_slash_index + 1:]

                    data_batch.append((parent, name, 1, 0))

                    # 当达到批量大小时，插入数据并清空批次列表
                    if len(data_batch) >= BATCH_SIZE:
                        insert_data_batch(data_batch)
                        data_batch.clear()

        # 插入剩余的数据
        if data_batch:
            insert_data_batch(data_batch)
    except Exception as e:
        logging.error(f"处理文件 {file_path} 时出错: {e}")

def process_all_files_in_folder(folder_path):
    """处理指定文件夹下的所有 TXT 文件"""
    for filename in os.listdir(folder_path):
        if filename.endswith('.txt'):
            file_path = os.path.join(folder_path, filename)
            process_file(file_path)

def deduplicate_records():
    """去重 x_search_nodes 表中的记录"""
    logging.info("开始去重 x_search_nodes 表中的记录.")
    with sqlite3.connect(DB_FILE) as conn:
        cursor = conn.cursor()
        cursor.execute('''
            DELETE FROM x_search_nodes 
            WHERE rowid NOT IN (
                SELECT MIN(rowid)
                FROM x_search_nodes
                GROUP BY parent, name
            )
        ''')
        conn.commit()
        logging.info("去重完成。")
       
def update_search_index():
    """更新 x_setting_items 表中的 search_index"""
    logging.info("更新 x_setting_items 表中的 search_index.")
    with sqlite3.connect(DB_FILE) as conn:
        cursor = conn.cursor()
        cursor.execute('''
            UPDATE x_setting_items
            SET value = 'database_non_full_text'
            WHERE key = 'search_index'
        ''')
        conn.commit()
        logging.info("search_index 的值已更新为 database_non_full_text。")
        
if __name__ == '__main__':
    # 更新 search_index
    update_search_index()  
    
    # 这里是用于调用数据插入的部分
    insert_data($SERVICE_TYPE, "$TOKEN", "$AList_URL", "$PASSWORD", $FORCE_LOGIN)

    create_table()     # 创建表
    clear_table()      # 清空表
    process_all_files_in_folder(TXT_FOLDER)  # 处理文件夹中的所有 TXT 文件
    deduplicate_records()  # 去重
    check_and_create_index()  # 检查并创建索引
    logging.info("数据处理完成。")
EOF
)

echo "$PYTHON_SCRIPT" > "$INSTALL_PATH/alist-temp/db_script.py"

python3 "$INSTALL_PATH/alist-temp/db_script.py"

echo "是否创建自动更新的脚本? (Y/N):"
read -r CREATE_SCRIPT

if [ "$CREATE_SCRIPT" == "Y" ] || [ "$CREATE_SCRIPT" == "y" ]; then
    # 创建更新脚本
    UPDATE_SCRIPT="$INSTALL_PATH/update_script.sh"
    cat <<EOF > "$UPDATE_SCRIPT"
#!/bin/bash
docker stop "$NEW_DOCKER_NAME"
docker cp "${DOCKER_NAME}:/index/." "$INSTALL_PATH/alist-temp/"

# 等待容器停止
sleep 3

python3 <<PYTHON_SCRIPT
import sqlite3
import logging
import os

# 配置日志输出格式
logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')

DB_FILE = "$INSTALL_PATH/data.db"  # 数据库文件路径
TXT_FOLDER = "$INSTALL_PATH/alist-temp"  # TXT 文件夹路径
BATCH_SIZE = 1000  # 批量插入大小

def clear_table():
    """清空 x_search_nodes 表"""
    with sqlite3.connect(DB_FILE) as conn:
        cursor = conn.cursor()
        cursor.execute('DELETE FROM x_search_nodes')
        conn.commit()
        logging.info("x_search_nodes 表已清空。")

def insert_data_batch(data_batch):
    """批量插入数据到 x_search_nodes 表"""
    with sqlite3.connect(DB_FILE) as conn:
        cursor = conn.cursor()
        cursor.executemany('''
        INSERT INTO x_search_nodes (parent, name, is_dir, size)
        VALUES (?, ?, ?, ?)
        ''', data_batch)
        conn.commit()

def process_file(file_path):
    """处理单个 TXT 文件并提取数据"""
    data_batch = []
    logging.info(f"开始处理文件: {file_path}")
    
    try:
        with open(file_path, 'r', encoding='utf-8') as file:
            for line in file:
                line = line.strip()
                if '#' in line:
                    parts = line.split('#')
                    path_with_file = parts[0].replace('./', '')
                else:
                    path_with_file = line.replace('./', '')

                last_slash_index = path_with_file.rfind('/')

                if last_slash_index != -1:
                    parent = '/' + path_with_file[:last_slash_index]
                    name = path_with_file[last_slash_index + 1:]

                    data_batch.append((parent, name, 1, 0))

                    # 当达到批量大小时，插入数据并清空批次列表
                    if len(data_batch) >= BATCH_SIZE:
                        insert_data_batch(data_batch)
                        data_batch.clear()

        # 插入剩余的数据
        if data_batch:
            insert_data_batch(data_batch)
    except Exception as e:
        logging.error(f"处理文件 {file_path} 时出错: {e}")

def process_all_files_in_folder(folder_path):
    """处理指定文件夹下的所有 TXT 文件"""
    for filename in os.listdir(folder_path):
        if filename.endswith('.txt'):
            file_path = os.path.join(folder_path, filename)
            process_file(file_path)

def deduplicate_records():
    """去重 x_search_nodes 表中的记录"""
    logging.info("开始去重 x_search_nodes 表中的记录.")
    with sqlite3.connect(DB_FILE) as conn:
        cursor = conn.cursor()
        cursor.execute('''
            DELETE FROM x_search_nodes 
            WHERE rowid NOT IN (
                SELECT MIN(rowid)
                FROM x_search_nodes
                GROUP BY parent, name
            )
        ''')
        conn.commit()
        logging.info("去重完成。")

if __name__ == '__main__':
    clear_table()  # 清空表
    process_all_files_in_folder(TXT_FOLDER)  # 处理文件夹中的所有 TXT 文件
    deduplicate_records()  # 去重
PYTHON_SCRIPT

docker start "$NEW_DOCKER_NAME"
EOF

    chmod +x "$UPDATE_SCRIPT"
    echo "更新脚本已创建: $UPDATE_SCRIPT"
    echo -e "\033[31m请将该脚本添加到任务计划中以设置更新频率。\033[0m"
fi

# 启动容器以确保它在运行
docker start "$NEW_DOCKER_NAME"
if [ $? -ne 0 ]; then
    echo "Error: Failed to start Docker container $NEW_DOCKER_NAME."
    exit 1
fi

# 初始化完成信息
docker exec -it "$NEW_DOCKER_NAME" ./alist admin random
if [ $? -ne 0 ]; then
    echo "Error: Failed to execute command in Docker container $NEW_DOCKER_NAME."
    exit 1
fi

echo -e "执行完毕,以上为初始账号密码，登录后\033[31m尽快修改密码\033[0m"
echo -e "由于以下目录小雅alsit带\033[31m表情\033[0m，命令创建无法表情，需要进储存\033[31m手动\033[0m修改为带表情的信息"
echo -e "\033[31m挂载路劲\033[0m和\033[31m根文件夹路径\033[0m都需要改"
echo "我的夸克分享"
echo "我的115分享"
echo "画质演示测试（4K，8K，HDR，Dolby）"
echo "我的PikPak分享"
