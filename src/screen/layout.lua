local layout = {
    fonts = {
        play14 = {
            font = "Play",
            size = 14
        },
        play16 = {
            font = "Play",
            size = 16
        },
        play18 = {
            font = "Play",
            size = 18
        },
        play24 = {
            font = "Play",
            size = 24
        },
        play36 = {
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
            fill = "#ffffffff",
            align = "h0,v3"
        },
        headerTextRight = {
            fill = "#ffffffff",
            align = "h2,v3"
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
            fill = "#111111ff"
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
            align = "h1,v3"
        },
        routeName = {
            fill = "#ffffffff",
            align = "h1,v3"
        },
        dataText = {
            fill = "#ffffffff",
            align = "h0,v1"
        },
        changePage = {
            fill = "#ffffffff",
            align = "h0,v1"
        },
        ---- Route editor -----
        routeEditTableHeader = {
            fill = "#181818ff",
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
        editRouteRouteName = {
            fill = "#ffffffff",
            align = "h0,v1"
        },
        split = {
            stroke = {
                distance = 2,
                color = "#181818FF"
            }
        }
    },
    pages = {
        routeSelection = {
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
                    style = "bkgLight",
                    pos1 = "(0,241)",
                    pos2 = "(1024,613)"
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
                    font = "play18"
                },
                {
                    type = "text",
                    layer = 1,
                    style = "info",
                    pos1 = "(280,40)",
                    font = "play36",
                    text = "$num(path{mass:total}:init{0}:format{%0.2f}:interval{0.5})"
                },
                {
                    type = "text",
                    layer = 1,
                    style = "units",
                    pos1 = "(260,70)",
                    font = "play14",
                    text = "$str(path{mass:totalUnit}:init{kg}:interval{0.5})"
                },
                {
                    type = "text",
                    layer = 1,
                    style = "headerText",
                    pos1 = "(300,20)",
                    text = "Current speed",
                    font = "play18"
                },
                {
                    type = "text",
                    layer = 1,
                    style = "info",
                    pos1 = "(460,40)",
                    font = "play36",
                    text = "$num(path{flightData:absSpeed}:init{0}:format{%0.2f}:interval{0.5})"
                },
                {
                    type = "text",
                    layer = 1,
                    style = "units",
                    pos1 = "(440,70)",
                    font = "play14",
                    text = "$str(path{flightData:speedUnit}:init{km/h}:interval{0.5})"
                },
                {
                    type = "text",
                    layer = 1,
                    style = "headerText",
                    pos1 = "(480,20)",
                    text = "Current route",
                    font = "play18"
                },
                {
                    type = "text",
                    layer = 1,
                    style = "info",
                    pos1 = "(640,40)",
                    font = "play36",
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
                    font = "play18"
                },
                {
                    type = "text",
                    layer = 1,
                    style = "info",
                    pos1 = "(280,160)",
                    font = "play36",
                    text = "$num(path{finalWp:distance}:init{0}:format{%0.2f}:interval{0.5})"
                },
                {
                    type = "text",
                    layer = 1,
                    style = "units",
                    pos1 = "(260,190)",
                    font = "play14",
                    text = "$str(path{finalWp:distanceUnit}:init{km}:interval{0.5})"
                },
                {
                    type = "text",
                    layer = 1,
                    style = "headerText",
                    pos1 = "(300,140)",
                    text = "Next WP distance",
                    font = "play18"
                },
                {
                    type = "text",
                    layer = 1,
                    style = "info",
                    pos1 = "(460,160)",
                    font = "play36",
                    text = "$num(path{nextWp:distance}:init{0}:format{%0.2f}:interval{0.5})"
                },
                {
                    type = "text",
                    layer = 1,
                    style = "units",
                    pos1 = "(440,190)",
                    font = "play14",
                    text = "$str(path{nextWp:distanceUnit}:init{km}:interval{0.5})"
                },
                {
                    type = "text",
                    layer = 1,
                    style = "headerText",
                    pos1 = "(480,140)",
                    text = "Deviation",
                    font = "play18"
                },
                {
                    type = "text",
                    layer = 1,
                    style = "info",
                    pos1 = "(640,160)",
                    font = "play36",
                    text = "$str(path{deviation:distance}:init{}:interval{0.5})"
                },
                {
                    type = "text",
                    layer = 1,
                    style = "units",
                    pos1 = "(620,190)",
                    font = "play14",
                    text = "m"
                },
                {
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
                    type = "text",
                    layer = 1,
                    visible = "$bool(path{fuel/atmo/[#]:visible}:init{false})",
                    text = "$num(path{fuel/atmo/[#]:percent}:init{0}:format{%0.0f})",
                    pos1 = "(700,40)",
                    font = "play14",
                    style = "fuelPercent",
                    replicate = {
                        x_count = 4,
                        x_step = 40
                    }
                },
                {
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
                    type = "text",
                    layer = 1,
                    visible = "$bool(path{fuel/space/[#]:visible}:init{false})",
                    text = "$num(path{fuel/space/[#]:percent}:init{0}:format{%0.0f})",
                    pos1 = "(870,40)",
                    font = "play14",
                    style = "fuelPercent",
                    replicate = {
                        x_count = 4,
                        x_step = 40
                    }
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
                    font = "play14",
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
                    pos1 = "(100, 350)",
                    visible = "$bool(path{routeSelection/routes/[#]:visible}:init{false})",
                    style = "routeName",
                    font = "play24",
                    text = "$str(path{routeSelection/routes/[#]:name}:init{route name})",
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
                    font = "play14",
                    hitable = false,
                    replicate = {
                        x_count = 6,
                        x_step = 160
                    }
                },
                {
                    type = "text",
                    layer = 1,
                    pos1 = "(930,585)",
                    text = "Edit |",
                    style = "changePage",
                    font = "play14",
                    mouse = {
                        click = {
                            command = "activatepage{routeEdit}"
                        }
                    }
                },

                {
                    type = "text",
                    layer = 1,
                    font = "play24",
                    style = "routeEditTableData",
                    pos1 = "(20,560)",
                    text = "<",
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
                    font = "play24",
                    style = "routeEditTableDataCentered",
                    pos1 = "(50,560)",
                    text = "$num(path{route:routePage}:init{1}:format{%0.0f})",
                },
                {
                    type = "text",
                    layer = 1,
                    font = "play24",
                    style = "routeEditTableDataRight",
                    pos1 = "(80,560)",
                    text = ">",
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
                    type = "text",
                    layer = 1,
                    pos1 = "(970,585)",
                    text = "Details",
                    style = "changePage",
                    font = "play14",
                    mouse = {
                        click = {
                            command = "activatepage{details}"
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
                    font = "play36",
                    pos1 = "(30,50)",
                    text = "Waypoints"
                },
                {
                    type = "text",
                    layer = 1,
                    style = "routeEditTableHeader",
                    font = "play14",
                    pos1 = "(30,90)",
                    text = "Waypoint name"
                },
                {
                    type = "text",
                    layer = 1,
                    style = "routeEditTableHeader",
                    font = "play14",
                    pos1 = "(300,90)",
                    text = "Delete"
                },
                {
                    type = "text",
                    layer = 1,
                    style = "routeEditTableHeader",
                    font = "play14",
                    pos1 = "(370,90)",
                    text = "Insert"
                },
                {
                    type = "text",
                    layer = 1,
                    style = "routeEditTableData",
                    font = "play24",
                    pos1 = "(30, 120)",
                    text = "$str(path{availableWaypoints/wayPoints/[#]:name}:init{})",
                    visible = "$bool(path{availableWaypoints/wayPoints/[#]:visible}:init{false})",
                    mouse = {
                        click = {
                            command =
                            "$str(path{availableWaypoints/wayPoints/[#]:pos}:init{}:format{set-waypoint -notify '%s'})"
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
                    font = "play24",
                    pos1 = "(300, 120)",
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
                    font = "play24",
                    pos1 = "(370, 120)",
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
                    font = "play24",
                    style = "routeEditTableData",
                    pos1 = "(20,560)",
                    text = "<",
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
                    font = "play24",
                    style = "routeEditTableDataCentered",
                    pos1 = "(50,560)",
                    text = "$num(path{availableWaypoints:currentPage}:init{1}:format{%0.0f})",
                },
                {
                    type = "text",
                    layer = 1,
                    font = "play24",
                    style = "routeEditTableDataRight",
                    pos1 = "(80,560)",
                    text = ">",
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
                    font = "play36",
                    pos1 = "(994,50)",
                    text = "Routes"
                },

                {
                    type = "text",
                    layer = 1,
                    font = "play24",
                    style = "editRouteRouteName",
                    pos1 = "(530,50)",
                    text = "$str(path{editRoute:selectRouteName}:init{})"
                },

                {
                    type = "text",
                    layer = 1,
                    style = "routeEditTableData",
                    font = "play24",
                    text = "<",
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
                    style = "routeEditTableData",
                    font = "play24",
                    text = ">",
                    pos1 = "(570,100)",
                    mouse = {
                        click = {
                            command = "#re-next-route"
                        },
                        inside = {
                            set_style = "routeEditHover"
                        }
                    }
                },
                {
                    type = "text",
                    layer = 1,
                    font = "play24",
                    style = "routeEditTableData",
                    pos1 = "(600,100)",
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
                    type = "text",
                    layer = 1,
                    font = "play24",
                    style = "routeEditTableData",
                    pos1 = "(670,100)",
                    text = "Delete",
                    mouse = {
                        click = {
                            command = "$str(path{editRoute:selectRouteName}:format{route-delete '%s'}:init{})"
                        },
                        inside = {
                            set_style = "routeEditHover"
                        }
                    }
                },

                {
                    type = "text",
                    layer = 1,
                    font = "play24",
                    style = "routeEditTableData",
                    pos1 = "(530,130)",
                    text = "$str(path{editRoute:name}:init{-}:format{Editing: %s})"
                },


                ----- Waypoints in route -----
                {
                    type = "text",
                    layer = 1,
                    style = "routeEditTableHeader",
                    font = "play14",
                    pos1 = "(530,170)",
                    text = "Waypoint name"
                },
                {
                    type = "text",
                    layer = 1,
                    style = "routeEditTableHeader",
                    font = "play14",
                    pos1 = "(800,170)",
                    text = "Up"
                },
                {
                    type = "text",
                    layer = 1,
                    style = "routeEditTableHeader",
                    font = "play14",
                    pos1 = "(850,170)",
                    text = "Down"
                },
                {
                    type = "text",
                    layer = 1,
                    style = "routeEditTableHeader",
                    font = "play14",
                    pos1 = "(900,170)",
                    text = "Remove"
                },
                {
                    type = "text",
                    layer = 1,
                    style = "routeEditTableDataRight",
                    font = "play24",
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
                    font = "play24",
                    pos1 = "(570, 200)",
                    text = "$str(path{editRoute/points/[#]:pointName}:init{})",
                    visible = "$bool(path{editRoute/points/[#]:visible}:init{false})",
                    mouse = {
                        click = {
                            command =
                            "$str(path{editRoute/points/[#]:position}:init{}:format{set-waypoint -notify '%s'})"
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
                    font = "play24",
                    pos1 = "(800, 200)",
                    text = "U",
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
                    type = "text",
                    layer = 1,
                    style = "routeEditTableData",
                    font = "play24",
                    pos1 = "(850, 200)",
                    text = "D",
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
                    font = "play24",
                    pos1 = "(900, 200)",
                    text = "R",
                    visible = "$bool(path{editRoute/points/[#]:visible}:init{false})",
                    mouse = {
                        click = {
                            command = "$num(path{editRoute/points/[#]:index}:init{0}:format{route-delete-pos %0.f})"
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
                    font = "play24",
                    text = "<",
                    pos1 = "(530,563)",
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
                    font = "play24",
                    style = "routeEditTableDataCentered",
                    pos1 = "(560,563)",
                    text = "$num(path{editRoute:currentPage}:init{1}:format{%0.0f})",
                },
                {
                    type = "text",
                    layer = 1,
                    style = "routeEditTableDataRight",
                    font = "play24",
                    text = ">",
                    pos1 = "(590,563)",
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
                    type = "text",
                    layer = 1,
                    style = "routeEditTableData",
                    font = "play24",
                    pos1 = "(590, 540)",
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
                    type = "text",
                    layer = 1,
                    style = "routeEditTableData",
                    font = "play24",
                    pos1 = "(750, 540)",
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
                    font = "play24",
                    style = "routeEditTableData",
                    pos1 = "(650,563)",
                    text = "Discard",
                    mouse = {
                        click = {
                            command = "route-discard"
                        },
                        inside = {
                            set_style = "routeEditHover"
                        }
                    }
                },
                {
                    type = "text",
                    layer = 1,
                    font = "play24",
                    style = "routeEditTableData",
                    pos1 = "(760,563)",
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
                    type = "text",
                    layer = 1,
                    font = "play24",
                    style = "routeEditTableDataRight",
                    pos1 = "(960,563)",
                    text = "Exit",
                    mouse = {
                        click = {
                            command = "activatepage{routeSelection}"
                        },
                        inside = {
                            set_style = "routeEditHoverRight"
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
                    pos1 = "(10, 10)",
                    text = "Version: GITINFO / DATEINFO",
                    layer = 1,
                    font = "play18",
                    style = "dataText"
                },
                {
                    type = "text",
                    layer = 1,
                    style = "dataText",
                    font = "play18",
                    text = "$str(path{:floor}:format{Floor detection: %s}:init{0})",
                    pos1 = "(10,30)"
                },
                {
                    type = "text",
                    layer = 1,
                    pos1 = "(960,590)",
                    text = "Routes",
                    style = "play14",
                    font = "play14",
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
