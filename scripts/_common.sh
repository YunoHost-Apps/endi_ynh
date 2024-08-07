#!/bin/bash

#=================================================
# COMMON VARIABLES
#=================================================

nodejs_version=16

#=================================================
# PERSONAL HELPERS
#=================================================

_ynh_caerp_build_ui() {
    ynh_use_nodejs

    pushd "$install_dir/caerp" 2>&1
        ynh_exec_as "$app" "$ynh_node_load_PATH" "$ynh_npm" --prefix js_sources install 2>&1
        ynh_exec_as "$app" "$ynh_node_load_PATH" "$ynh_npm" --prefix vue_sources install 2>&1

        ynh_exec_as "$app" "$ynh_node_load_PATH" make prodjs devjs prodjs2 devjs2 2>&1 \
            || ynh_die --message="Build of javascript code failed, maybe because of high RAM usage!"
    popd 2>&1
}

_ynh_caerp_build_python() {
    _ynh_python_venv_setup --venv_dir="$install_dir/venv"
    python_venv_site_packages=$(_ynh_python_venv_get_site_packages_dir -d "$install_dir/venv")

    pushd "$install_dir/caerp" 2>&1
        ynh_exec_as "$app" "$install_dir/venv/bin/python3" -m pip install -r requirements.txt
        ynh_exec_as "$app" "$install_dir/venv/bin/python3" ./setup.py install 2>&1
    popd 2>&1

    chmod 750 "$install_dir"
    chmod -R o-rwx "$install_dir"
    chown -R "$app:www-data" "$install_dir"
}

_ynh_caerp_migratedb() {
    pushd "$install_dir" 2>&1
        ynh_exec_as "$app" "$install_dir/venv/bin/caerp-admin" "$install_dir/caerp.ini" \
            syncdb
    popd 2>&1
 }

_ynh_caerp_add_admin() {
    pushd "$install_dir" 2>&1
        ynh_exec_as "$app" "$install_dir/venv/bin/caerp-admin" "$install_dir/caerp.ini" \
            useradd --group=admin --user="$admin" --pwd="$password" --email="admin@$domain"
    popd 2>&1
 }


#=================================================
# Python Venv HELPERS
#=================================================

_ynh_python_venv_setup() {
    local -A args_array=( [d]=venv_dir= [p]=packages= )
    local venv_dir
    local packages
    ynh_handle_getopts_args "$@"

    ynh_exec_as "$app" python3 -m venv "$venv_dir"

    if [[ -n "${packages:-}" ]]; then
        IFS=" " read -r -a pip_packages <<< "$packages"
        "$venv_dir/bin/python3" -m pip install --upgrade pip "${pip_packages[@]}"
    fi
}

_ynh_python_venv_get_site_packages_dir() {
    local -A args_array=( [d]=venv_dir= )
    local venv_dir
    ynh_handle_getopts_args "$@"

    "$venv_dir/bin/python3" -c 'import sysconfig; print(sysconfig.get_paths()["purelib"])'
}

#=================================================
# EXPERIMENTAL HELPERS
#=================================================

#=================================================
# FUTURE OFFICIAL HELPERS
#=================================================
