local ver = require("version_out")
local layout = {
    fonts = {
        version = {
            font = "Play",
            size = 18
        },
        offline = {
            font = "Play",
            size = 36
        }
    },
    styles = {
        version = {
            fill = "#ffffffff",
            align = "h2,v4"
        },
        bkgDark = {
            fill = "#2F3637ff"
        },
        offline = {
            fill = "#ffffffff",
            align = "h1,v2"
        }
    },
    pages = {
        offline = {
            components = {
                {
                    comment = "background",
                    type = "box",
                    layer = 1,
                    style = "bkgDark",
                    pos1 = "(0,0)",
                    pos2 = "(1024,613)"
                },
                {
                    type = "text",
                    layer = 1,
                    pos1 = "(512,500)",
                    text = "YFS - Offline",
                    font = "offline",
                    style = "offline"
                },
                {
                    type = "image",
                    layer = 2,
                    pos1 = "(260,180)",
                    dimensions = "(180,210)",
                    url = "assets.prod.novaquark.com/94617/dcf01ca2-4e9d-410c-ac90-f806634671d9.png",
                    style = "bkgDark"
                },
                {
                    type = "image",
                    layer = 2,
                    pos1 = "(640,180)",
                    dimensions = "(180,180)",
                    url = "assets.prod.novaquark.com/70604/92eeafe5-527f-49f5-af7a-cb0c4a771f5b.png",
                    style = "bkgDark"
                },
                {
                    type = "text",
                    pos1 = "(1004,593)",
                    text = ver.APP_VERSION,
                    layer = 1,
                    font = "version",
                    style = "version"
                }
            }
        }
    }
}

return layout
