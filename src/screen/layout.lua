local layout = {
    fonts = {
        header = {
            font = "Play",
            size = 18
        },
        info = {
            font = "Play",
            size = 36
        },
        units = {
            font = "Play",
            size = 14
        },
        fuelPercent = {
            font = "Play",
            size = 14
        },
        routeEndpointText = {
            font = "Play",
            size = 14
        },
        routeName = {
            font = "Play",
            size = 24
        },
        dataFont = {
            font = "Play",
            size = 18
        },
        changePage = {
            font = "Play",
            size = 14
        }
    },
    styles = {
        hidden = {
            fill = "#00000000"
        },
        bkgDark = {
            fill = "#2F3637ff"
        },
        bkgLight = {
            fill = "#aaaaaaff",
            stroke = {
                distance = 1,
                color = "#aaaaaaff"
            }
        },
        headerText = {
            fill = "#ffffffff",
            align = "h0,v1"
        },
        info = {
            fill = "#ffffffff",
            align = "h2,v1"
        },
        units = {
            fill = "#ffffffff",
            align = "h2,v1"
        },
        fuelBack = {
            fill = "#000000ff"
        },
        fuelAtmo = {
            fill = "#2f6fd0ff"
        },
        fuelSpace = {
            fill = "#d0d02fff"
        },
        fuelPercent = {
            fill = "#ffffffff",
            align = "h1,v2"
        },
        routeButton = {
            fill = "#546263ff"
        },
        routeButtonHover = {
            fill = "#2f6fd0ff"
        },
        routeEndpointText = {
            fill = "#ffffffff",
            align = "h1,v2"
        },
        routeName = {
            fill = "#ffffffff",
            align = "h1,v2"
        },
        dataText = {
            fill = "#ffffffff",
            align = "h0,v1"
        },
        changePage = {
            fill = "#ffffffff",
            align = "h0,v1"
        }
    },
    pages = {
        routeSelection = {
            components = {
                {
                    comment = "background",
                    type = "box",
                    layer = 1,
                    style = "bkgDark",
                    pos1 = "(0,0)",
                    pos2 = "(1024,240)"
                },
                {
                    comment = "background",
                    type = "box",
                    layer = 1,
                    style = "bkgLight",
                    pos1 = "(0,241)",
                    pos2 = "(1024,613)"
                },
                {
                    comment = "current-icon-outer",
                    type = "box",
                    layer = 1,
                    style = "bkgLight",
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
                    comment = "current-icon-center",
                    type = "box",
                    layer = 1,
                    style = "bkgLight",
                    pos1 = "(60,40)",
                    pos2 = "(80,60)"
                },
                {
                    type = "text",
                    layer = 1,
                    style = "headerText",
                    pos1 = "(120,20)",
                    text = "Total mass",
                    font = "header"
                },
                {
                    type = "text",
                    layer = 1,
                    style = "info",
                    pos1 = "(280,40)",
                    font = "info",
                    text = "$num(path{mass:total}:init{0}:format{%0.2f}:interval{0.5})"
                },
                {
                    type = "text",
                    layer = 1,
                    style = "units",
                    pos1 = "(260,70)",
                    font = "units",
                    text = "$str(path{mass:totalUnit}:init{kg}:interval{0.5})"
                },
                {
                    type = "text",
                    layer = 1,
                    style = "headerText",
                    pos1 = "(300,20)",
                    text = "Current speed",
                    font = "header"
                },
                {
                    type = "text",
                    layer = 1,
                    style = "info",
                    pos1 = "(460,40)",
                    font = "info",
                    text = "$num(path{flightData:absSpeed}:init{0}:format{%0.2f}:interval{0.5})"
                },
                {
                    type = "text",
                    layer = 1,
                    style = "units",
                    pos1 = "(440,70)",
                    font = "units",
                    text = "$str(path{flightData:speedUnit}:init{km/h}:interval{0.5})"
                },
                {
                    type = "text",
                    layer = 1,
                    style = "headerText",
                    pos1 = "(480,20)",
                    text = "Current route",
                    font = "header"
                },
                {
                    type = "text",
                    layer = 1,
                    style = "info",
                    pos1 = "(640,40)",
                    font = "info",
                    text = "$str(path{route/current:name}:init{-}:interval{0.5})"
                },
                {
                    comment = "target-icon-vert",
                    type = "box",
                    layer = 1,
                    style = "bkgLight",
                    pos1 = "(60,140)",
                    pos2 = "(80,160)",
                    replicate = {
                        x_count = 1,
                        y_count = 2,
                        y_step = 40
                    }
                },
                {
                    comment = "target-icon-hor",
                    type = "box",
                    layer = 1,
                    style = "bkgLight",
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
                    font = "header"
                },
                {
                    type = "text",
                    layer = 1,
                    style = "info",
                    pos1 = "(280,160)",
                    font = "info",
                    text = "$num(path{finalWp:distance}:init{0}:format{%0.2f}:interval{0.5})"
                },
                {
                    type = "text",
                    layer = 1,
                    style = "units",
                    pos1 = "(260,190)",
                    font = "units",
                    text = "$str(path{finalWp:distanceUnit}:init{km}:interval{0.5})"
                },
                {
                    type = "text",
                    layer = 1,
                    style = "headerText",
                    pos1 = "(300,140)",
                    text = "Next WP distance",
                    font = "header"
                },
                {
                    type = "text",
                    layer = 1,
                    style = "info",
                    pos1 = "(460,160)",
                    font = "info",
                    text = "$num(path{nextWp:distance}:init{0}:format{%0.2f}:interval{0.5})"
                },
                {
                    type = "text",
                    layer = 1,
                    style = "units",
                    pos1 = "(440,190)",
                    font = "units",
                    text = "$str(path{nextWp:distanceUnit}:init{km}:interval{0.5})"
                },
                {
                    type = "text",
                    layer = 1,
                    style = "headerText",
                    pos1 = "(480,140)",
                    text = "Deviation",
                    font = "header"
                },
                {
                    type = "text",
                    layer = 1,
                    style = "info",
                    pos1 = "(640,160)",
                    font = "info",
                    text = "$num(path{deviation:distance}:init{0}:format{%0.3f}:interval{0.5})"
                },
                {
                    type = "text",
                    layer = 1,
                    style = "units",
                    pos1 = "(620,190)",
                    font = "units",
                    text = "m"
                },
                {
                    comment = "atmo-fuelBack",
                    type = "box",
                    layer = 1,
                    style = "fuelBack",
                    visible = "$bool(path{fuel/atmo/[#]:visible}:init{false})",
                    pos1 = "(680,20)",
                    pos2 = "(720,220)",
                    replicate = {
                        x_count = 4,
                        x_step = 40
                    }
                },
                {
                    comment = "atmo-fuel-bar",
                    type = "box",
                    layer = 1,
                    style = "fuelAtmo",
                    visible = "$bool(path{fuel/atmo/[#]:visible}:init{false})",
                    pos1 = "$vec2(path{fuel/atmo/[#]:factorBar}:init{(680,220)}:percent{(680,20)})",
                    pos2 = "(720,220)",
                    replicate = {
                        x_count = 4,
                        x_step = 40
                    }
                },
                {
                    comment = "atmo-percent",
                    type = "text",
                    layer = 1,
                    visible = "$bool(path{fuel/atmo/[#]:visible}:init{false})",
                    text = "$num(path{fuel/atmo/[#]:percent}:init{0}:format{%0.0f})",
                    pos1 = "(700,40)",
                    font = "fuelPercent",
                    style = "fuelPercent",
                    replicate = {
                        x_count = 4,
                        x_step = 40
                    }
                },
                {
                    comment = "space-fuelBack",
                    type = "box",
                    layer = 1,
                    style = "fuelBack",
                    visible = "$bool(path{fuel/space/[#]:visible}:init{false})",
                    pos1 = "(850,20)",
                    pos2 = "(890,220)",
                    replicate = {
                        x_count = 4,
                        x_step = 40
                    }
                },
                {
                    comment = "space-fuel-bar",
                    type = "box",
                    layer = 1,
                    style = "fuelSpace",
                    visible = "$bool(path{fuel/space/[#]:visible}:init{false})",
                    pos1 = "$vec2(path{fuel/space/[#]:factorBar}:init{(850,220)}:percent{(850,20)})",
                    pos2 = "(890,220)",
                    replicate = {
                        x_count = 4,
                        x_step = 40
                    }
                },
                {
                    comment = "space-percent",
                    type = "text",
                    layer = 1,
                    visible = "$bool(path{fuel/space/[#]:visible}:init{false})",
                    text = "$num(path{fuel/space/[#]:percent}:init{0}:format{%0.0f})",
                    pos1 = "(870,40)",
                    font = "fuelPercent",
                    style = "fuelPercent",
                    replicate = {
                        x_count = 4,
                        x_step = 40
                    }
                },
                {
                    comment = "route upper",
                    type = "box",
                    layer = 1,
                    visible = "$bool(path{route/[#]:visible}:init{false})",
                    pos1 = "(40,280)",
                    pos2 = "(160,320)",
                    style = "routeButton",
                    mouse = {
                        inside = {
                            set_style = "routeButtonHoverr"
                        },
                        click = {
                            command = "$str(path{route/[#]:name}:init{}:format{route-activate '%s'})"
                        }
                    },
                    replicate = {
                        x_count = 5,
                        x_step = 160
                    }
                },
                {
                    comment = "route upper cover left",
                    type = "box",
                    layer = 1,
                    visible = "$bool(path{route/[#]:visible}:init{false})",
                    pos1 = "(40,300)",
                    pos2 = "(60,320)",
                    style = "bkgLight",
                    replicate = {
                        x_count = 5,
                        x_step = 160
                    }
                },
                {
                    comment = "route upper cover right",
                    type = "box",
                    layer = 1,
                    visible = "$bool(path{route/[#]:visible}:init{false})",
                    pos1 = "(140,300)",
                    pos2 = "(160,320)",
                    style = "bkgLight",
                    replicate = {
                        x_count = 5,
                        x_step = 160
                    }
                },
                {
                    type = "text",
                    layer = 1,
                    visible = "$bool(path{route/[#]:visible}:init{false})",
                    pos1 = "(100,300)",
                    text = "End",
                    style = "routeEndpointText",
                    font = "routeEndpointText",
                    hitable = false,
                    replicate = {
                        x_count = 5,
                        x_step = 160
                    }
                },
                {
                    comment = "route lower",
                    type = "box",
                    layer = 1,
                    visible = "$bool(path{route/[#]:visible}:init{false})",
                    pos1 = "(40,380)",
                    pos2 = "(160,420)",
                    style = "routeButton",
                    mouse = {
                        inside = {
                            set_style = "routeButtonHoverr"
                        },
                        click = {
                            command = "$str(path{route/[#]:name}:init{}:format{route-activate '%s' -reverse})"
                        }
                    },
                    replicate = {
                        x_count = 5,
                        x_step = 160
                    }
                },
                {
                    comment = "route name",
                    type = "text",
                    layer = 1,
                    pos1 = "(100, 350)",
                    visible = "$bool(path{route/[#]:visible}:init{false})",
                    style = "routeName",
                    font = "routeName",
                    text = "$str(path{route/[#]:name}:init{route name})",
                    replicate = {
                        x_count = 5,
                        x_step = 160
                    }
                },
                {
                    comment = "route lower cover left",
                    type = "box",
                    layer = 1,
                    visible = "$bool(path{route/[#]:visible}:init{false})",
                    pos1 = "(40,380)",
                    pos2 = "(60,400)",
                    style = "bkgLight",
                    replicate = {
                        x_count = 5,
                        x_step = 160
                    }
                },
                {
                    comment = "route lower cover right",
                    type = "box",
                    layer = 1,
                    visible = "$bool(path{route/[#]:visible}:init{false})",
                    pos1 = "(140,380)",
                    pos2 = "(160,400)",
                    style = "bkgLight",
                    replicate = {
                        x_count = 5,
                        x_step = 160
                    }
                },
                {
                    type = "text",
                    layer = 1,
                    visible = "$bool(path{route/[#]:visible}:init{false})",
                    pos1 = "(100,400)",
                    text = "Beginning",
                    style = "routeEndpointText",
                    font = "routeEndpointText",
                    hitable = false,
                    replicate = {
                        x_count = 5,
                        x_step = 160
                    }
                },
                {
                    type = "text",
                    layer = 1,
                    pos1 = "(970,590)",
                    text = "<data>",
                    style = "changePage",
                    font = "changePage",
                    mouse = {
                        click = {
                            command = "activatepage{details}"
                        }
                    }
                }
            }
        },
        details = {
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
                    pos1 = "(10, 10)",
                    text = "Version: GITINFO / DATEINFO",
                    layer = 1,
                    font = "dataFont",
                    style = "dataText"
                },
                {
                    type = "text",
                    layer = 1,
                    style = "dataText",
                    font = "dataFont",
                    text = "$str(path{:floor}:format{Floor detection: %s}:init{0})",
                    pos1 = "(10,30)"
                },
                {
                    type = "text",
                    layer = 1,
                    pos1 = "(960,590)",
                    text = "<routes>",
                    style = "changePage",
                    font = "changePage",
                    mouse = {
                        click = {
                            command = "activatepage{routeSelection}"
                        }
                    }
                }
            }
        }
    }
}

return layout
