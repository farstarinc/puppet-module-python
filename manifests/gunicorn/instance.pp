define python::gunicorn::instance($venv,
                                  $src,
                                  $ensure=present,
                                  $wsgi_module="",
                                  $django=false,
                                  $django_settings="",
                                  $version=undef,
                                  $workers=1,
                                  $upstart=false) {
  $is_present = $ensure == "present"

  $rundir = $python::gunicorn::rundir
  $logdir = $python::gunicorn::logdir
  $owner = $python::gunicorn::owner
  $group = $python::gunicorn::group

  $initscript = $upstart ? {
    false => "/etc/init.d/gunicorn-${name}",
    true => "/etc/init/gunicorn-${name}.conf",
    default => "/etc/init/${upstart}.conf"
  }
  $pidfile = "$rundir/$name.pid"
  $socket = "unix:$rundir/$name.sock"
  $logfile = "$logdir/$name.log"

  if $wsgi_module == "" and !$django {
    fail("If you're not using Django you have to define a WSGI module.")
  }

  if $django_settings != "" and !$django {
    fail("If you're not using Django you can't define a settings file.")
  }

  if $wsgi_module != "" and $django {
    fail("If you're using Django you can't define a WSGI module.")
  }

  $gunicorn_package = $version ? {
    undef => "gunicorn",
    default => "gunicorn==${version}",
  }

  $venv_parent_dir = regsubst($venv, '^(.+)/.+/?$', '\1')
  if !defined(File[$venv_parent_dir]) {
    file { $parent_dir:
      ensure => directory,
      owner => $owner,
      group => $group,
    }
  }

  if $is_present {
    python::pip::install {
      "$gunicorn_package in $venv":
        package => $gunicorn_package,
        ensure => $ensure,
        venv => $venv,
        owner => $owner,
        group => $group,
        require => Python::Venv::Isolate[$venv],
        before => File[$initscript];

      # for --name support in gunicorn:
      "setproctitle in $venv":
        package => "setproctitle",
        ensure => $ensure,
        venv => $venv,
        owner => $owner,
        group => $group,
        require => Python::Venv::Isolate[$venv],
        before => File[$initscript];
    }
  }

  file { $initscript:
    ensure => $ensure,
    content => $upstart ? {
        false => template("python/gunicorn.init.erb"),
        default => template("python/gunicorn.upstart.erb"),
    },
    mode => 744,
    require => File["/etc/logrotate.d/gunicorn-${name}"],
  }

  file { "/etc/logrotate.d/gunicorn-${name}":
    ensure => $ensure,
    content => template("python/gunicorn.logrotate.erb"),
  }
  
  service { "gunicorn-${name}":
    name  => $upstart ? {
      false => "gunicorn-${name}",
      true => "gunicorn-${name}",
      default => $upstart,
    },
    provider => $upstart ? {
        false => undef,
        default => "upstart",
    },
    ensure => $is_present,
    enable => $is_present,
    hasstatus => $is_present,
    hasrestart => $is_present,
    subscribe => $ensure ? {
      'present' => File[$initscript],
      default => undef,
    },
    require => $ensure ? {
      'present' => File[$initscript],
      default => undef,
    },
    before => $ensure ? {
      'absent' => File[$initscript],
      default => undef,
    },
  }
}
