metadata    :name        => "choria",
            :description => "PuppetDB based discovery method",
            :author      => "R.I.Pienaar <rip@devco.net>",
            :license     => "Apache-2.0",
            :version     => "0.1",
            :url         => "https://choria.io/",
            :timeout     => 2

discovery do
    capabilities [:classes, :facts, :identity, :agents]
end


