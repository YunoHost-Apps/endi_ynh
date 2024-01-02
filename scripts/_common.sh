#!/bin/bash

#=================================================
# COMMON VARIABLES
#=================================================

#=================================================
# PERSONAL HELPERS
#=================================================

__ynh_endi_patch_src() {
    # Patching requirements.txt to use system provided Cython
    cython_version=$(cython3 --version 2>&1 | sed 's|Cython version ||')
    sed -i "s|Cython=.*|Cython==$cython_version|" "$install_dir/endi/requirements.txt"
}

__ynh_endi_build() {
    #=================================================
    # NPM setup
    #=================================================
    ynh_use_nodejs
    ynh_install_nodejs --nodejs_version=16

    pushd "$install_dir/endi" 2>&1
        ynh_exec_as $app $ynh_node_load_PATH $ynh_npm --prefix js_sources install 2>&1
        ynh_exec_as $app $ynh_node_load_PATH $ynh_npm --prefix vue_sources install 2>&1
        ynh_exec_as $app $ynh_node_load_PATH make prodjs devjs prodjs2 devjs2 2>&1 \
            || ynh_die --message="Build of javascript code failed, maybe because of high RAM usage!"
    popd 2>&1

    #=================================================
    # Python + Virtualenv setup
    #=================================================
    ynh_script_progression --message="Installing Python dependencies and Endi..." --weight=1

    __ynh_python_venv_setup --venv_dir="$install_dir/venv"
    python_venv_site_packages=$(__ynh_python_venv_get_site_packages_dir -d "$install_dir/venv")
    chown -R $app:www-data "$install_dir/venv"

    pushd "$install_dir/endi" 2>&1
        ynh_exec_as $app "$install_dir/venv/bin/python3" ./setup.py install 2>&1
    popd 2>&1

    chmod 750 "$install_dir"
    chmod -R o-rwx "$install_dir"
    chown -R $app:www-data "$install_dir"
}

__ynh_endi_migratedb() {
    pushd "$install_dir" 2>&1
        ynh_exec_as $app "$install_dir/venv/bin/endi-admin" "$install_dir/endi.ini" \
            syncdb
    popd 2>&1
 }

__ynh_endi_add_admin() {
    pushd "$install_dir" 2>&1
        ynh_exec_as $app "$install_dir/venv/bin/endi-admin" "$install_dir/endi.ini" \
            useradd --group=admin --user="admin" --pwd="$password" --email="admin@$domain"
    popd 2>&1
 }


#=================================================
# Python Venv HELPERS
#=================================================

__ynh_python_venv_setup() {
    local -A args_array=( [d]=venv_dir= [p]=packages= )
    local venv_dir
    local packages
    ynh_handle_getopts_args "$@"

    python3 -m venv --system-site-packages "$venv_dir"

    if [[ -n "${packages:-}" ]]; then
        IFS=" " read -r -a pip_packages <<< "$packages"
        "$venv_dir/bin/python3" -m pip install --upgrade pip "${pip_packages[@]}"
    fi
}

__ynh_python_venv_get_site_packages_dir() {
    local -A args_array=( [d]=venv_dir= )
    local venv_dir
    ynh_handle_getopts_args "$@"

    "$venv_dir/bin/python3" -c 'import sysconfig; print(sysconfig.get_paths()["purelib"])'
}

#=================================================
# Redis HELPERS
#=================================================

# get the first available redis database
#
# usage: ynh_redis_get_free_db
# | returns: the database number to use
ynh_redis_get_free_db() {
    local result max db
    result=$(redis-cli INFO keyspace)

    # get the num
    max=$(cat /etc/redis/redis.conf | grep ^databases | grep -Eow "[0-9]+")

    db=0
    # default Debian setting is 15 databases
    for i in $(seq 0 "$max")
    do
        if ! echo "$result" | grep -q "db$i"
        then
            db=$i
            break 1
        fi
        db=-1
    done

    test "$db" -eq -1 && ynh_die "No available Redis databases..."

    echo "$db"
}

# Create a master password and set up global settings
# Please always call this script in install and restore scripts
#
# usage: ynh_redis_remove_db database
# | arg: database - the database to erase
ynh_redis_remove_db() {
    local db=$1
    redis-cli -n "$db" flushall
}

#=================================================
# EXPERIMENTAL HELPERS
#=================================================

#=================================================
# FUTURE OFFICIAL HELPERS
#=================================================
