-- Shared map dimensions. Keep visuals, drop distribution and base defenses aligned.
return table.freeze({
 PlotCount=8,
 PlotRadius=200,
 PlotSize=86,
 PetPadCount=8,
 YardRadius=95,
 SpawnRadius=78,
 RouteStart=95,
 BarrierStart=100,
 LaserStart=110,
 RouteHalfWidth=12.5,
 OuterRoadRadius=285,
 -- The perimeter fence round the island (JunkyardRefresh.Perimeter): only
 -- decoration, so an invisible wall stands in it (MapBootstrap).
 IslandBorderRadius=312,
})
