local layout = {
    fonts = {
        p14 = {
            font = "Play",
            size = 14
        },
        p18 = {
            font = "Play",
            size = 18
        },
        p24 = {
            font = "Play",
            size = 24
        },
        p36 = {
            font = "Play",
            size = 36
        },
    },
    styles = {
        bkgDark = {
            fill = "#000000ff"
        },
        bkgLight = {
            fill = "#111111ff",
        },
        icon = {
            fill = "#ffffffff",
        },
        headerText = {
            fill = "#555555ff",
            align = "h0,v3"
        },
        headerTextRight = {
            fill = "#555555ff",
            align = "h2,v3"
        },
        info = {
            fill = "#ffffffff",
            align = "h2,v3"
        },
        units = {
            fill = "#ffffffff",
            align = "h2,v3"
        },
        routeButton = {
            align = "h1,v2",
            fill = "#546263ff",
        },
        routeButtonHover = {
            fill = "#2f6fd0ff"
        },
        routeCover = {
            fill = "#111111ff",
            stroke = {
                color = "#111111ff",
                distance = 1
            }
        },
        routeEndpointText = {
            fill = "#000000ff",
            align = "h1,v2"
        },
        routeName = {
            fill = "#ffffffff",
            align = "h1,v3"
        },
        ---- Route editor -----
        routeEditTableHeader = {
            fill = "#888888ff",
            align = "h0, v3"
        },
        routeEditTableData = {
            fill = "#ffffffff",
            align = "h0,v3"
        },
        routeEditTableDataCentered = {
            fill = "#ffffffff",
            align = "h1,v3"
        },
        routeEditTableDataRight = {
            fill = "#ffffffff",
            align = "h2,v3"
        },
        routeEditHover = {
            fill = "#2f6fd0ff",
            align = "h0,v3"
        },
        routeEditHoverRight = {
            fill = "#2f6fd0ff",
            align = "h2,v3"
        },
        routeEditHoverRed = {
            fill = "#ff0000ff",
            align = "h0,v3"
        },
        routeEditTableDataCenteredHover = {
            fill = "#2f6fd0ff",
            align = "h1,v3"
        },
        editRouteRouteName = {
            fill = "#ffffffff",
            align = "h0,v3"
        },
        split = {
            stroke = {
                distance = 2,
                color = "#181818FF"
            }
        }
    },
    pages = {
        status = {
            components = {
                {
                    type = "box",
                    layer = 1,
                    style = "bkgDark",
                    pos1 = "(0,0)",
                    pos2 = "(1024,240)"
                },
                {
                    type = "box",
                    layer = 1,
                    style = "icon",
                    pos1 = "(40,20)",
                    pos2 = "(60,40)",
                    replicate = {
                        x_count = 2,
                        y_count = 2,
                        x_step = 40,
                        y_step = 40
                    }
                },
                {
                    type = "box",
                    layer = 1,
                    style = "icon",
                    pos1 = "(60,40)",
                    pos2 = "(80,60)"
                },
                {
                    type = "text",
                    layer = 1,
                    style = "headerText",
                    pos1 = "(120,20)",
                    text = "Total mass",
                    font = "p18"
                },
                {
                    type = "text",
                    layer = 1,
                    style = "info",
                    pos1 = "(280,50)",
                    font = "p36",
                    text = "$num(path{mass:total}:init{0}:format{%0.2f}:interval{0.5})"
                },
                {
                    type = "text",
                    layer = 1,
                    style = "units",
                    pos1 = "(260,70)",
                    font = "p14",
                    text = "$str(path{mass:totalUnit}:init{kg}:interval{0.5})"
                },
                {
                    type = "text",
                    layer = 1,
                    style = "headerText",
                    pos1 = "(300,20)",
                    text = "Current speed",
                    font = "p18"
                },
                {
                    type = "text",
                    layer = 1,
                    style = "info",
                    pos1 = "(460,50)",
                    font = "p36",
                    text = "$num(path{flightData:absSpeed}:init{0}:format{%0.2f}:interval{0.5})"
                },
                {
                    type = "text",
                    layer = 1,
                    style = "units",
                    pos1 = "(440,70)",
                    font = "p14",
                    text = "$str(path{flightData:speedUnit}:init{km/h}:interval{0.5})"
                },
                {
                    type = "text",
                    layer = 1,
                    style = "headerText",
                    pos1 = "(480,20)",
                    text = "Current route",
                    font = "p18"
                },
                {
                    type = "text",
                    layer = 1,
                    style = "info",
                    pos1 = "(640,50)",
                    font = "p36",
                    text = "$str(path{route/current:name}:init{-}:interval{0.5})"
                },
                {
                    type = "box",
                    layer = 1,
                    style = "icon",
                    pos1 = "(60,140)",
                    pos2 = "(80,160)",
                    replicate = {
                        x_count = 1,
                        y_count = 2,
                        y_step = 40
                    }
                },
                {
                    type = "box",
                    layer = 1,
                    style = "icon",
                    pos1 = "(40,160)",
                    pos2 = "(60,180)",
                    replicate = {
                        x_count = 2,
                        y_count = 1,
                        x_step = 40
                    }
                },
                {
                    type = "text",
                    layer = 1,
                    style = "headerText",
                    pos1 = "(120,140)",
                    text = "Remaining distance",
                    font = "p18"
                },
                {
                    type = "text",
                    layer = 1,
                    style = "info",
                    pos1 = "(280,170)",
                    font = "p36",
                    text = "$num(path{finalWp:distance}:init{0}:format{%0.2f}:interval{0.5})"
                },
                {
                    type = "text",
                    layer = 1,
                    style = "units",
                    pos1 = "(260,190)",
                    font = "p14",
                    text = "$str(path{finalWp:distanceUnit}:init{km}:interval{0.5})"
                },
                {
                    type = "text",
                    layer = 1,
                    style = "headerText",
                    pos1 = "(300,140)",
                    text = "Next WP distance",
                    font = "p18"
                },
                {
                    type = "text",
                    layer = 1,
                    style = "info",
                    pos1 = "(460,170)",
                    font = "p36",
                    text = "$num(path{nextWp:distance}:init{0}:format{%0.2f}:interval{0.5})"
                },
                {
                    type = "text",
                    layer = 1,
                    style = "units",
                    pos1 = "(440,190)",
                    font = "p14",
                    text = "$str(path{nextWp:distanceUnit}:init{km}:interval{0.5})"
                },
                {
                    type = "text",
                    layer = 1,
                    style = "headerText",
                    pos1 = "(480,140)",
                    text = "Deviation",
                    font = "p18"
                },
                {
                    type = "text",
                    layer = 1,
                    style = "info",
                    pos1 = "(640,170)",
                    font = "p36",
                    text = "$str(path{deviation:distance}:init{}:interval{0.5})"
                },
                {
                    type = "text",
                    layer = 1,
                    style = "units",
                    pos1 = "(620,190)",
                    font = "p14",
                    text = "m"
                }
            }
        },
        floor = {
            components = {
                {
                    type = "box",
                    layer = 1,
                    style = "bkgLight",
                    pos1 = "(0,241)",
                    pos2 = "(1024,613)"
                },
                {
                    type = "box",
                    layer = 1,
                    visible = true,
                    pos1 = "(40,280)",
                    pos2 = "(160,320)",
                    style = "routeButton",
                    mouse = {
                        inside = {
                            set_style = "routeButtonHover"
                        },
                        click = {
                            command = "$str(path{floorSelection:routeName}:init{}:format{route-activate '%s'})"
                        }
                    }
                },
                {
                    type = "box",
                    layer = 1,
                    visible = true,
                    pos1 = "(40,300)",
                    pos2 = "(60,320)",
                    style = "routeCover",
                    replicate = {
                        x_count = 2,
                        x_step = 160
                    }
                },
                {
                    type = "box",
                    layer = 1,
                    visible = true,
                    pos1 = "(140,300)",
                    pos2 = "(160,320)",
                    style = "routeCover",
                    replicate = {
                        x_count = 2,
                        x_step = 160
                    }
                },
                {
                    type = "text",
                    layer = 1,
                    visible = true,
                    pos1 = "(100,300)",
                    text = "End",
                    style = "routeEndpointText",
                    font = "p14",
                    hitable = false
                },
                {
                    type = "box",
                    layer = 1,
                    visible = true,
                    pos1 = "(40,380)",
                    pos2 = "(160,420)",
                    style = "routeButton",
                    mouse = {
                        inside = {
                            set_style = "routeButtonHover"
                        },
                        click = {
                            command =
                            "$str(path{floorSelection:routeName}:init{}:format{route-activate '%s' -index 1})"
                        }
                    }
                },
                {
                    type = "text",
                    layer = 1,
                    pos1 = "(100, 360)",
                    visible = true,
                    style = "routeName",
                    font = "p24",
                    text = "$str(path{floorSelection:routeName}:init{})"
                },
                {
                    type = "box",
                    layer = 1,
                    visible = true,
                    pos1 = "(40,380)",
                    pos2 = "(60,400)",
                    style = "routeCover"
                },
                {
                    type = "box",
                    layer = 1,
                    visible = true,
                    pos1 = "(140,380)",
                    pos2 = "(160,400)",
                    style = "routeCover"
                },
                {
                    type = "text",
                    layer = 1,
                    visible = true,
                    pos1 = "(100,400)",
                    text = "Start",
                    style = "routeEndpointText",
                    font = "p14",
                    hitable = false
                },
                {
                    type = "text",
                    layer = 1,
                    style = "routeEditTableData",
                    font = "p24",
                    pos1 = "(180, 300)",
                    text = "$num(path{floorSelection/points/[#]:index}:init{0})",
                    visible = "$bool(path{floorSelection/points/[#]:visible}:init{false})",
                    replicate = {
                        y_count = 8,
                        y_step = 30,
                        x_count = 3,
                        x_step = 260,
                        column_mode = true
                    }
                },
                {
                    type = "text",
                    layer = 1,
                    style = "routeEditTableData",
                    font = "p24",
                    pos1 = "(220, 300)",
                    text = "$str(path{floorSelection/points/[#]:name}:init{})",
                    visible = "$bool(path{floorSelection/points/[#]:visible}:init{false})",
                    mouse = {
                        click = {
                            command =
                            "$str(path{floorSelection/points/[#]:activate}:init{}:format{%s})"
                        },
                        inside = {
                            set_style = "routeEditHover"
                        }
                    },
                    replicate = {
                        y_count = 8,
                        y_step = 30,
                        x_count = 3,
                        x_step = 260,
                        column_mode = true
                    }
                },
                {
                    type = "text",
                    layer = 1,
                    font = "p24",
                    style = "routeEditTableData",
                    pos1 = "(20,600)",
                    text = "$num(path{floorSelection:currentPage}:init{1}:format{< %0.0f})",
                    mouse = {
                        click = {
                            command = "#fl-prev-floor-page"
                        },
                        inside = {
                            set_style = "routeEditHover"
                        }
                    }
                },
                {
                    type = "text",
                    layer = 1,
                    font = "p24",
                    style = "routeEditTableDataRight",
                    pos1 = "(120,600)",
                    text = "$num(path{floorSelection:pageCount}:init{1}:format{ / %0.0f >})",
                    mouse = {
                        click = {
                            command = "#fl-next-floor-page"
                        },
                        inside = {
                            set_style = "routeEditHoverRight"
                        }
                    }
                },
                {
                    type = "image",
                    layer = 2,
                    pos1 = "(935,580)",
                    dimensions = "(20,20)",
                    sub = "(0,480)",
                    subDimensions = "(20,20)",
                    style = "icon",
                    url = "assets.prod.novaquark.com/94617/4158c26e-9db3-4a28-9468-b84207e44eec.png",
                    mouse = {
                        click = {
                            command = "activatepage{status,routeSelection}"
                        },
                        inside = {
                            set_style = "routeEditHover"
                        }
                    }
                },
                {
                    type = "text",
                    layer = 1,
                    font = "p24",
                    style = "routeEditTableData",
                    pos1 = "(960,600)",
                    text = "Exit",
                    mouse = {
                        click = {
                            command = "activatepage{status,routeSelection}"
                        },
                        inside = {
                            set_style = "routeEditHover"
                        }
                    }
                }
            }
        },
        routeSelection = {
            components = {
                {
                    type = "box",
                    layer = 1,
                    style = "bkgLight",
                    pos1 = "(0,241)",
                    pos2 = "(1024,613)"
                },
                {
                    type = "box",
                    layer = 1,
                    visible = "$bool(path{routeSelection/routes/[#]:visible}:init{false})",
                    pos1 = "(40,280)",
                    pos2 = "(160,320)",
                    style = "routeButton",
                    mouse = {
                        inside = {
                            set_style = "routeButtonHover"
                        },
                        click = {
                            command = "$str(path{routeSelection/routes/[#]:name}:init{}:format{route-activate '%s'})"
                        }
                    },
                    replicate = {
                        x_count = 6,
                        x_step = 160
                    }
                },
                {
                    type = "box",
                    layer = 1,
                    visible = "$bool(path{routeSelection/routes/[#]:visible}:init{false})",
                    pos1 = "(40,300)",
                    pos2 = "(60,320)",
                    style = "routeCover",
                    replicate = {
                        x_count = 6,
                        x_step = 160
                    }
                },
                {
                    type = "box",
                    layer = 1,
                    visible = "$bool(path{routeSelection/routes/[#]:visible}:init{false})",
                    pos1 = "(140,300)",
                    pos2 = "(160,320)",
                    style = "routeCover",
                    replicate = {
                        x_count = 6,
                        x_step = 160
                    }
                },
                {
                    type = "text",
                    layer = 1,
                    visible = "$bool(path{routeSelection/routes/[#]:visible}:init{false})",
                    pos1 = "(100,300)",
                    text = "End",
                    style = "routeEndpointText",
                    font = "p14",
                    hitable = false,
                    replicate = {
                        x_count = 6,
                        x_step = 160
                    }
                },
                {
                    type = "box",
                    layer = 1,
                    visible = "$bool(path{routeSelection/routes/[#]:visible}:init{false})",
                    pos1 = "(40,380)",
                    pos2 = "(160,420)",
                    style = "routeButton",
                    mouse = {
                        inside = {
                            set_style = "routeButtonHover"
                        },
                        click = {
                            command =
                            "$str(path{routeSelection/routes/[#]:name}:init{}:format{route-activate '%s' -index 1})"
                        }
                    },
                    replicate = {
                        x_count = 6,
                        x_step = 160
                    }
                },
                {
                    type = "text",
                    layer = 1,
                    pos1 = "(100, 360)",
                    visible = "$bool(path{routeSelection/routes/[#]:visible}:init{false})",
                    style = "routeName",
                    font = "p24",
                    text = "$str(path{routeSelection/routes/[#]:name}:init{})",
                    replicate = {
                        x_count = 6,
                        x_step = 160
                    }
                },
                {
                    type = "box",
                    layer = 1,
                    visible = "$bool(path{routeSelection/routes/[#]:visible}:init{false})",
                    pos1 = "(40,380)",
                    pos2 = "(60,400)",
                    style = "routeCover",
                    replicate = {
                        x_count = 6,
                        x_step = 160
                    }
                },
                {
                    type = "box",
                    layer = 1,
                    visible = "$bool(path{routeSelection/routes/[#]:visible}:init{false})",
                    pos1 = "(140,380)",
                    pos2 = "(160,400)",
                    style = "routeCover",
                    replicate = {
                        x_count = 6,
                        x_step = 160
                    }
                },
                {
                    type = "text",
                    layer = 1,
                    visible = "$bool(path{routeSelection/routes/[#]:visible}:init{false})",
                    pos1 = "(100,400)",
                    text = "Start",
                    style = "routeEndpointText",
                    font = "p14",
                    hitable = false,
                    replicate = {
                        x_count = 6,
                        x_step = 160
                    }
                },
                {
                    type = "box",
                    layer = 1,
                    visible = "$bool(path{routeSelection/routes/[#]:visible}:init{false})",
                    pos1 = "(40,440)",
                    pos2 = "(160,460)",
                    style = "routeButton",
                    mouse = {
                        inside = {
                            set_style = "routeButtonHover"
                        },
                        click = {
                            command =
                            "$str(path{routeSelection/routes/[#]:name}:init{}:format{floor '%s'})"
                        }
                    },
                    replicate = {
                        x_count = 6,
                        x_step = 160
                    }
                },
                {
                    type = "text",
                    layer = 1,
                    visible = "$bool(path{routeSelection/routes/[#]:visible}:init{false})",
                    pos1 = "(100,450)",
                    text = "Waypoints",
                    style = "routeEndpointText",
                    font = "p14",
                    hitable = false,
                    replicate = {
                        x_count = 6,
                        x_step = 160
                    }
                },
                {
                    type = "text",
                    layer = 1,
                    font = "p24",
                    style = "routeEditTableData",
                    pos1 = "(20,600)",
                    text = "$num(path{routeSelection:routePage}:init{1}:format{< %0.0f})",
                    mouse = {
                        click = {
                            command = "#rsel-prev-route-page"
                        },
                        inside = {
                            set_style = "routeEditHover"
                        }
                    }
                },
                {
                    type = "text",
                    layer = 1,
                    font = "p24",
                    style = "routeEditTableDataRight",
                    pos1 = "(120,600)",
                    text = "$num(path{routeSelection:pageCount}:init{1}:format{ / %0.0f >})",
                    mouse = {
                        click = {
                            command = "#rsel-next-route-page"
                        },
                        inside = {
                            set_style = "routeEditHoverRight"
                        }
                    }
                },
                {
                    type = "image",
                    layer = 2,
                    pos1 = "(800,580)",
                    dimensions = "(20,20)",
                    sub = "(0,460)",
                    subDimensions = "(20,20)",
                    style = "icon",
                    url = "assets.prod.novaquark.com/94617/4158c26e-9db3-4a28-9468-b84207e44eec.png",
                    mouse = {
                        click = {
                            command = "activatepage{routeEdit}"
                        },
                        inside = {
                            set_style = "routeEditHover"
                        }
                    }
                },
                {
                    type = "text",
                    layer = 1,
                    pos1 = "(825,600)",
                    text = "Edit",
                    style = "routeEditTableData",
                    font = "p24",
                    mouse = {
                        click = {
                            command = "activatepage{routeEdit}"
                        },
                        inside = {
                            set_style = "routeEditHover"
                        }
                    }
                },
                {
                    type = "image",
                    layer = 2,
                    pos1 = "(880,580)",
                    dimensions = "(20,20)",
                    sub = "(0,0)",
                    subDimensions = "(20,20)",
                    style = "icon",
                    url = "assets.prod.novaquark.com/94617/4158c26e-9db3-4a28-9468-b84207e44eec.png",
                    mouse = {
                        click = {
                            command = "activatepage{details}"
                        },
                        inside = {
                            set_style = "routeEditHover"
                        }
                    }
                },
                {
                    type = "text",
                    layer = 1,
                    pos1 = "(905,600)",
                    text = "Details",
                    style = "routeEditTableData",
                    font = "p24",
                    mouse = {
                        click = {
                            command = "activatepage{details}"
                        },
                        inside = {
                            set_style = "routeEditHover"
                        }
                    }
                }
            }
        },
        routeEdit = {
            components = {
                {
                    type = "box",
                    layer = 1,
                    style = "bkgDark",
                    pos1 = "(0,0)",
                    pos2 = "(1024,613)"
                },
                {
                    type = "text",
                    layer = 1,
                    style = "headerText",
                    font = "p36",
                    pos1 = "(30,50)",
                    text = "Waypoints"
                },
                {
                    type = "text",
                    layer = 1,
                    style = "routeEditTableHeader",
                    font = "p14",
                    pos1 = "(30,110)",
                    text = "Waypoint name"
                },
                {
                    type = "text",
                    layer = 1,
                    style = "routeEditTableHeader",
                    font = "p14",
                    pos1 = "(300,110)",
                    text = "Delete"
                },
                {
                    type = "text",
                    layer = 1,
                    style = "routeEditTableHeader",
                    font = "p14",
                    pos1 = "(370,110)",
                    text = "Insert"
                },
                {
                    type = "text",
                    layer = 1,
                    style = "routeEditTableHeader",
                    font = "p14",
                    pos1 = "(430,110)",
                    text = "Ins + facing"
                },
                {
                    type = "text",
                    layer = 1,
                    style = "routeEditTableData",
                    font = "p24",
                    pos1 = "(30, 140)",
                    text = "$str(path{availableWaypoints/wayPoints/[#]:name}:init{})",
                    visible = "$bool(path{availableWaypoints/wayPoints/[#]:visible}:init{false})",
                    mouse = {
                        click = {
                            command =
                            "$str(path{availableWaypoints/wayPoints/[#]:pos}:init{}:format{set-waypoint -notify %s})"
                        },
                        inside = {
                            set_style = "routeEditHover"
                        }
                    },
                    replicate = {
                        y_count = 10,
                        y_step = 30
                    }
                },
                {
                    type = "text",
                    layer = 1,
                    style = "routeEditTableData",
                    font = "p24",
                    pos1 = "(300, 140)",
                    text = "X",
                    visible = "$bool(path{availableWaypoints/wayPoints/[#]:visible}:init{false})",
                    mouse = {
                        click = {
                            command = "$str(path{availableWaypoints/wayPoints/[#]:name}:init{}:format{pos-delete '%s'})"
                        },
                        inside = {
                            set_style = "routeEditHoverRed"
                        }
                    },
                    replicate = {
                        y_count = 10,
                        y_step = 30
                    }
                },
                {
                    type = "text",
                    layer = 1,
                    style = "routeEditTableData",
                    font = "p24",
                    pos1 = "(370, 140)",
                    text = ">>",
                    visible = "$bool(path{availableWaypoints/wayPoints/[#]:visible}:init{false})",
                    mouse = {
                        click = {
                            command =
                            "$str(path{availableWaypoints/wayPoints/[#]:name}:init{}:format{route-add-named-pos '%s'})"
                        },
                        inside = {
                            set_style = "routeEditHover"
                        }
                    },
                    replicate = {
                        y_count = 10,
                        y_step = 30
                    }
                },
                {
                    type = "text",
                    layer = 1,
                    style = "routeEditTableData",
                    font = "p24",
                    pos1 = "(430, 140)",
                    text = ">>",
                    visible = "$bool(path{availableWaypoints/wayPoints/[#]:visible}:init{false})",
                    mouse = {
                        click = {
                            command =
                            "$str(path{availableWaypoints/wayPoints/[#]:name}:init{}:format{route-add-named-pos '%s' -lockdir})"
                        },
                        inside = {
                            set_style = "routeEditHover"
                        }
                    },
                    replicate = {
                        y_count = 10,
                        y_step = 30
                    }
                },
                {
                    type = "image",
                    layer = 2,
                    pos1 = "(165,540)",
                    dimensions = "(20,20)",
                    sub = "(0,1040)",
                    subDimensions = "(20,20)",
                    style = "icon",
                    url = "assets.prod.novaquark.com/94617/4158c26e-9db3-4a28-9468-b84207e44eec.png",
                    mouse = {
                        click = {
                            command = "pos-save-current-as -auto"
                        },
                        inside = {
                            set_style = "routeEditHover"
                        }
                    }
                },
                {
                    type = "text",
                    layer = 1,
                    style = "routeEditTableDataCentered",
                    font = "p24",
                    pos1 = "(256, 560)",
                    text = "Add Current",
                    visible = true,
                    mouse = {
                        click = {
                            command = "pos-save-current-as -auto"
                        },
                        inside = {
                            set_style = "routeEditTableDataCenteredHover"
                        }
                    }
                },
                {
                    type = "text",
                    layer = 1,
                    font = "p24",
                    style = "routeEditTableData",
                    pos1 = "(20,520)",
                    text = "$num(path{availableWaypoints:currentPage}:init{1}:format{< %0.0f})",
                    mouse = {
                        click = {
                            command = "#re-prev-wp-page"
                        },
                        inside = {
                            set_style = "routeEditHover"
                        }
                    }
                },
                {
                    type = "text",
                    layer = 1,
                    font = "p24",
                    style = "routeEditTableDataRight",
                    pos1 = "(120,520)",
                    text = "$num(path{availableWaypoints:pageCount}:init{1}:format{/ %0.0f >})",
                    mouse = {
                        click = {
                            command = "#re-next-wp-page"
                        },
                        inside = {
                            set_style = "routeEditHoverRight"
                        }
                    }
                },

                {
                    type = "line",
                    layer = 1,
                    pos1 = "(512,50)",
                    pos2 = "(512,563)",
                    style = "split"
                },

                ------- Routes -------
                {
                    type = "text",
                    layer = 1,
                    style = "headerTextRight",
                    font = "p36",
                    pos1 = "(994,50)",
                    text = "Routes"
                },

                {
                    type = "text",
                    layer = 1,
                    font = "p24",
                    style = "editRouteRouteName",
                    pos1 = "(530,50)",
                    text = "$str(path{editRoute:selectRouteName}:init{})"
                },

                {
                    type = "text",
                    layer = 1,
                    style = "routeEditTableData",
                    font = "p24",
                    text = "$num(path{editRoute:ix}:init{1}:format{< %0.0f})",
                    pos1 = "(530,100)",
                    mouse = {
                        click = {
                            command = "#re-previous-route"
                        },
                        inside = {
                            set_style = "routeEditHover"
                        }
                    }
                },
                {
                    type = "text",
                    layer = 1,
                    style = "routeEditTableDataRight",
                    font = "p24",
                    text = "$num(path{editRoute:count}:init{1}:format{/ %0.0f >})",
                    pos1 = "(630,100)",
                    mouse = {
                        click = {
                            command = "#re-next-route"
                        },
                        inside = {
                            set_style = "routeEditHoverRight"
                        }
                    }
                },
                {
                    type = "image",
                    layer = 2,
                    pos1 = "(815,84)",
                    dimensions = "(20,20)",
                    sub = "(0,20)",
                    subDimensions = "(20,20)",
                    style = "icon",
                    url = "assets.prod.novaquark.com/94617/4158c26e-9db3-4a28-9468-b84207e44eec.png",
                    mouse = {
                        click = {
                            command = "$str(path{editRoute:selectRouteName}:format{route-edit '%s'}:init{})"
                        },
                        inside = {
                            set_style = "routeEditHover"
                        }
                    }
                },
                {
                    type = "text",
                    layer = 1,
                    font = "p24",
                    style = "routeEditTableData",
                    pos1 = "(840,100)",
                    text = "Edit",
                    mouse = {
                        click = {
                            command = "$str(path{editRoute:selectRouteName}:format{route-edit '%s'}:init{})"
                        },
                        inside = {
                            set_style = "routeEditHover"
                        }
                    }
                },
                {
                    type = "image",
                    layer = 2,
                    pos1 = "(895,84)",
                    dimensions = "(20,20)",
                    sub = "(0,120)",
                    subDimensions = "(20,20)",
                    style = "icon",
                    url = "assets.prod.novaquark.com/94617/4158c26e-9db3-4a28-9468-b84207e44eec.png",
                    mouse = {
                        click = {
                            command = "$str(path{editRoute:selectRouteName}:format{route-delete '%s'}:init{})"
                        },
                        inside = {
                            set_style = "routeEditHoverRed"
                        }
                    }
                },
                {
                    type = "text",
                    layer = 1,
                    font = "p24",
                    style = "routeEditTableData",
                    pos1 = "(920,100)",
                    text = "Delete",
                    mouse = {
                        click = {
                            command = "$str(path{editRoute:selectRouteName}:format{route-delete '%s'}:init{})"
                        },
                        inside = {
                            set_style = "routeEditHoverRed"
                        }
                    }
                },

                ----- Waypoints in route -----
                {
                    type = "text",
                    layer = 1,
                    style = "routeEditTableHeader",
                    font = "p14",
                    pos1 = "(530,170)",
                    text = "Waypoint name"
                },
                {
                    type = "text",
                    layer = 1,
                    style = "routeEditTableHeader",
                    font = "p14",
                    pos1 = "(720,170)",
                    text = "Gate"
                },
                {
                    type = "text",
                    layer = 1,
                    style = "routeEditTableHeader",
                    font = "p14",
                    pos1 = "(770,170)",
                    text = "Skip"
                },
                {
                    type = "text",
                    layer = 1,
                    style = "routeEditTableHeader",
                    font = "p14",
                    pos1 = "(820,170)",
                    text = "Sel"
                },
                {
                    type = "text",
                    layer = 1,
                    style = "routeEditTableHeader",
                    font = "p14",
                    pos1 = "(870,170)",
                    text = "Up"
                },
                {
                    type = "text",
                    layer = 1,
                    style = "routeEditTableHeader",
                    font = "p14",
                    pos1 = "(900,170)",
                    text = "Down"
                },
                {
                    type = "text",
                    layer = 1,
                    style = "routeEditTableHeader",
                    font = "p14",
                    pos1 = "(950,170)",
                    text = "Remove"
                },
                {
                    type = "text",
                    layer = 1,
                    style = "routeEditTableDataRight",
                    font = "p24",
                    pos1 = "(545, 200)",
                    text = "$num(path{editRoute/points/[#]:index}:init{0}:format{%0.f})",
                    visible = "$bool(path{editRoute/points/[#]:visible}:init{false})",
                    replicate = {
                        y_count = 10,
                        y_step = 30
                    }
                },
                {
                    type = "text",
                    layer = 1,
                    style = "routeEditTableData",
                    font = "p24",
                    pos1 = "(570, 200)",
                    text = "$str(path{editRoute/points/[#]:pointName}:init{})",
                    visible = "$bool(path{editRoute/points/[#]:visible}:init{false})",
                    mouse = {
                        click = {
                            command =
                            "$str(path{editRoute/points/[#]:position}:init{}:format{set-waypoint -notify %s})"
                        },
                        inside = {
                            set_style = "routeEditHover"
                        }
                    },
                    replicate = {
                        y_count = 10,
                        y_step = 30
                    }
                },
                {
                    type = "image",
                    layer = 2,
                    pos1 = "(720,180)",
                    dimensions = "(20,20)",
                    sub = "(0,180)",
                    subDimensions = "(20,20)",
                    style = "icon",
                    url = "assets.prod.novaquark.com/94617/4158c26e-9db3-4a28-9468-b84207e44eec.png",
                    visible = "$bool(path{editRoute/points/[#]:gate}:init{false})",
                    mouse = {
                        click = {
                            command =
                            "$num(path{editRoute/points/[#]:index}:init{0}:format{route-set-pos-option -ix %d -toggleGate})"
                        },
                        inside = {
                            set_style = "routeEditHover"
                        }
                    },
                    replicate = {
                        y_count = 10,
                        y_step = 30
                    }
                },
                {
                    type = "image",
                    layer = 2,
                    pos1 = "(720,180)",
                    dimensions = "(20,20)",
                    sub = "(0,160)",
                    subDimensions = "(20,20)",
                    style = "icon",
                    url = "assets.prod.novaquark.com/94617/4158c26e-9db3-4a28-9468-b84207e44eec.png",
                    visible = "$bool(path{editRoute/points/[#]:notGate}:init{false})",
                    mouse = {
                        click = {
                            command =
                            "$num(path{editRoute/points/[#]:index}:init{0}:format{route-set-pos-option -ix %d -toggleGate})"
                        },
                        inside = {
                            set_style = "routeEditHover"
                        }
                    },
                    replicate = {
                        y_count = 10,
                        y_step = 30
                    }
                },
                {
                    type = "image",
                    layer = 2,
                    pos1 = "(770,180)",
                    dimensions = "(20,20)",
                    sub = "(0,180)",
                    subDimensions = "(20,20)",
                    style = "icon",
                    url = "assets.prod.novaquark.com/94617/4158c26e-9db3-4a28-9468-b84207e44eec.png",
                    visible = "$bool(path{editRoute/points/[#]:skippable}:init{false})",
                    mouse = {
                        click = {
                            command =
                            "$num(path{editRoute/points/[#]:index}:init{0}:format{route-set-pos-option -ix %d -toggleSkippable})"
                        },
                        inside = {
                            set_style = "routeEditHover"
                        }
                    },
                    replicate = {
                        y_count = 10,
                        y_step = 30
                    }
                },
                {
                    type = "image",
                    layer = 2,
                    pos1 = "(770,180)",
                    dimensions = "(20,20)",
                    sub = "(0,160)",
                    subDimensions = "(20,20)",
                    style = "icon",
                    url = "assets.prod.novaquark.com/94617/4158c26e-9db3-4a28-9468-b84207e44eec.png",
                    visible = "$bool(path{editRoute/points/[#]:notSkippable}:init{false})",
                    mouse = {
                        click = {
                            command =
                            "$num(path{editRoute/points/[#]:index}:init{0}:format{route-set-pos-option -ix %d -toggleSkippable})"
                        },
                        inside = {
                            set_style = "routeEditHover"
                        }
                    },
                    replicate = {
                        y_count = 10,
                        y_step = 30
                    }
                },
                {
                    type = "image",
                    layer = 2,
                    pos1 = "(820,180)",
                    dimensions = "(20,20)",
                    sub = "(0,180)",
                    subDimensions = "(20,20)",
                    style = "icon",
                    url = "assets.prod.novaquark.com/94617/4158c26e-9db3-4a28-9468-b84207e44eec.png",
                    visible = "$bool(path{editRoute/points/[#]:selectable}:init{false})",
                    mouse = {
                        click = {
                            command =
                            "$num(path{editRoute/points/[#]:index}:init{0}:format{route-set-pos-option -ix %d -toggleSelectable})"
                        },
                        inside = {
                            set_style = "routeEditHover"
                        }
                    },
                    replicate = {
                        y_count = 10,
                        y_step = 30
                    }
                },
                {
                    type = "image",
                    layer = 2,
                    pos1 = "(820,180)",
                    dimensions = "(20,20)",
                    sub = "(0,160)",
                    subDimensions = "(20,20)",
                    style = "icon",
                    url = "assets.prod.novaquark.com/94617/4158c26e-9db3-4a28-9468-b84207e44eec.png",
                    visible = "$bool(path{editRoute/points/[#]:notSelectable}:init{false})",
                    mouse = {
                        click = {
                            command =
                            "$num(path{editRoute/points/[#]:index}:init{0}:format{route-set-pos-option -ix %d -toggleSelectable})"
                        },
                        inside = {
                            set_style = "routeEditHover"
                        }
                    },
                    replicate = {
                        y_count = 10,
                        y_step = 30
                    }
                },
                {
                    type = "image",
                    layer = 2,
                    pos1 = "(870,180)",
                    dimensions = "(20,20)",
                    sub = "(0,320)", -- Up
                    subDimensions = "(20,20)",
                    style = "icon",
                    url = "assets.prod.novaquark.com/94617/4158c26e-9db3-4a28-9468-b84207e44eec.png",
                    visible = "$bool(path{editRoute/points/[#]:visible}:init{false})",
                    mouse = {
                        click = {
                            command = "$num(path{editRoute/points/[#]:index}:init{0}:format{route-move-pos-back %0.f})"
                        },
                        inside = {
                            set_style = "routeEditHover"
                        }
                    },
                    replicate = {
                        y_count = 10,
                        y_step = 30
                    }
                },
                {
                    type = "image",
                    layer = 2,
                    pos1 = "(900,180)",
                    dimensions = "(20,20)",
                    sub = "(0,300)", -- Down
                    subDimensions = "(20,20)",
                    style = "icon",
                    url = "assets.prod.novaquark.com/94617/4158c26e-9db3-4a28-9468-b84207e44eec.png",
                    visible = "$bool(path{editRoute/points/[#]:visible}:init{false})",
                    mouse = {
                        click = {
                            command =
                            "$num(path{editRoute/points/[#]:index}:init{0}:format{route-move-pos-forward %0.f})"
                        },
                        inside = {
                            set_style = "routeEditHover"
                        }
                    },
                    replicate = {
                        y_count = 10,
                        y_step = 30
                    }
                },
                {
                    type = "text",
                    layer = 1,
                    style = "routeEditTableData",
                    font = "p24",
                    pos1 = "(950, 200)",
                    text = "<<",
                    visible = "$bool(path{editRoute/points/[#]:visible}:init{false})",
                    mouse = {
                        click = {
                            command = "$num(path{editRoute/points/[#]:index}:init{0}:format{route-delete-pos %0.f})"
                        },
                        inside = {
                            set_style = "routeEditHoverRed"
                        }
                    },
                    replicate = {
                        y_count = 10,
                        y_step = 30
                    }
                },

                {
                    type = "text",
                    layer = 1,
                    style = "routeEditTableData",
                    font = "p24",
                    text = "$num(path{editRoute:currentPage}:init{1}:format{< %0.0f})",
                    pos1 = "(530,520)",
                    mouse = {
                        click = {
                            command = "#re-prev-point-page"
                        },
                        inside = {
                            set_style = "routeEditHover"
                        }
                    }
                },
                {
                    type = "text",
                    layer = 1,
                    style = "routeEditTableDataRight",
                    font = "p24",
                    text = "$num(path{editRoute:pageCount}:init{1}:format{/ %0.0f >})",
                    pos1 = "(630,520)",
                    mouse = {
                        click = {
                            command = "#re-next-point-page"
                        },
                        inside = {
                            set_style = "routeEditHoverRight"
                        }
                    }
                },
                {
                    type = "image",
                    layer = 2,
                    pos1 = "(605,540)",
                    dimensions = "(20,20)",
                    sub = "(0,1040)",
                    subDimensions = "(20,20)",
                    style = "icon",
                    url = "assets.prod.novaquark.com/94617/4158c26e-9db3-4a28-9468-b84207e44eec.png",
                    mouse = {
                        click = {
                            command = "route-add-current-pos"
                        },
                        inside = {
                            set_style = "routeEditHover"
                        }
                    }
                },
                {
                    type = "text",
                    layer = 1,
                    style = "routeEditTableData",
                    font = "p24",
                    pos1 = "(630, 560)",
                    text = "Add current",
                    visible = true,
                    mouse = {
                        click = {
                            command = "route-add-current-pos"
                        },
                        inside = {
                            set_style = "routeEditHover"
                        }
                    }
                },
                {
                    type = "image",
                    layer = 2,
                    pos1 = "(765,540)",
                    dimensions = "(20,20)",
                    sub = "(0,1060)",
                    subDimensions = "(20,20)",
                    style = "icon",
                    url = "assets.prod.novaquark.com/94617/4158c26e-9db3-4a28-9468-b84207e44eec.png",
                    mouse = {
                        click = {
                            command = "route-add-current-pos -lockdir"
                        },
                        inside = {
                            set_style = "routeEditHover"
                        }
                    }
                },
                {
                    type = "text",
                    layer = 1,
                    style = "routeEditTableData",
                    font = "p24",
                    pos1 = "(790, 560)",
                    text = "Add + facing",
                    visible = true,
                    mouse = {
                        click = {
                            command = "route-add-current-pos -lockdir"
                        },
                        inside = {
                            set_style = "routeEditHover"
                        }
                    }
                },
                {
                    type = "text",
                    layer = 1,
                    font = "p24",
                    style = "routeEditTableData",
                    pos1 = "(630,600)",
                    text = "X Discard",
                    mouse = {
                        click = {
                            command = "route-discard"
                        },
                        inside = {
                            set_style = "routeEditHoverRed"
                        }
                    }
                },
                {
                    type = "image",
                    layer = 2,
                    pos1 = "(755,580)",
                    dimensions = "(20,20)",
                    sub = "(0,100)",
                    subDimensions = "(20,20)",
                    style = "icon",
                    url = "assets.prod.novaquark.com/94617/4158c26e-9db3-4a28-9468-b84207e44eec.png",
                    mouse = {
                        click = {
                            command = "route-save"
                        },
                        inside = {
                            set_style = "routeEditHover"
                        }
                    }
                },
                {
                    type = "text",
                    layer = 1,
                    font = "p24",
                    style = "routeEditTableData",
                    pos1 = "(780,600)",
                    text = "Save",
                    mouse = {
                        click = {
                            command = "route-save"
                        },
                        inside = {
                            set_style = "routeEditHover"
                        }
                    }
                },
                {
                    type = "image",
                    layer = 2,
                    pos1 = "(935,580)",
                    dimensions = "(20,20)",
                    sub = "(0,480)",
                    subDimensions = "(20,20)",
                    style = "icon",
                    url = "assets.prod.novaquark.com/94617/4158c26e-9db3-4a28-9468-b84207e44eec.png",
                    mouse = {
                        click = {
                            command = "activatepage{status,routeSelection}"
                        },
                        inside = {
                            set_style = "routeEditHover"
                        }
                    }
                },
                {
                    type = "text",
                    layer = 1,
                    font = "p24",
                    style = "routeEditTableData",
                    pos1 = "(960,600)",
                    text = "Exit",
                    mouse = {
                        click = {
                            command = "activatepage{status,routeSelection}"
                        },
                        inside = {
                            set_style = "routeEditHover"
                        }
                    }
                }
            }
        },
        details = {
            components = {
                {
                    type = "box",
                    layer = 1,
                    style = "bkgDark",
                    pos1 = "(0,0)",
                    pos2 = "(1024,613)"
                },
                {
                    type = "text",
                    pos1 = "(10, 25)",
                    text = "Version: GITINFO / DATEINFO",
                    layer = 1,
                    font = "p24",
                    style = "routeEditTableData"
                },
                {
                    type = "text",
                    layer = 1,
                    style = "routeEditTableData",
                    font = "p24",
                    text = "$str(path{:floor}:format{Floor detection: %s}:init{0})",
                    pos1 = "(10,50)"
                },
                {
                    type = "image",
                    layer = 2,
                    pos1 = "(935,580)",
                    dimensions = "(20,20)",
                    sub = "(0,480)",
                    subDimensions = "(20,20)",
                    style = "icon",
                    url = "assets.prod.novaquark.com/94617/4158c26e-9db3-4a28-9468-b84207e44eec.png",
                    mouse = {
                        click = {
                            command = "activatepage{status,routeSelection}"
                        },
                        inside = {
                            set_style = "routeEditHover"
                        }
                    }
                },
                {
                    type = "text",
                    layer = 1,
                    font = "p24",
                    style = "routeEditTableData",
                    pos1 = "(960,600)",
                    text = "Exit",
                    mouse = {
                        click = {
                            command = "activatepage{status,routeSelection}"
                        },
                        inside = {
                            set_style = "routeEditHover"
                        }
                    }
                }
            }
        }
    }
}

return layout
