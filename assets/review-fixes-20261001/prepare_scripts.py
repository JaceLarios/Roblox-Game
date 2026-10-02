from pathlib import Path
P=Path(__file__).resolve().parent;src=P.parent/'remaining-fusions'
s=(src/'import.edit.luau').read_text().replace('RemainingModelImport','ReviewModelImport').replace('RemainingModelsStaging_','ReviewModelsStaging_').replace('remaining-fusions/import/','review-fixes-20261001/import/')
(P/'import-fusions.edit.luau').write_text(s)
s=(src/'install.edit.luau').read_text().replace('RemainingModelImport','ReviewModelImport').replace('RemainingModelsVerification','ReviewModelsVerification').replace('BeforeRemainingModels_','BeforeReviewModels_').replace('#models==52','#models==17').replace('Expected 52 models','Expected 17 models')
s=s.replace("assert(m:GetAttribute('StagingComplete'),m.Name)","""assert(m:GetAttribute('StagingComplete'),m.Name)
 local original=assert(templates:FindFirstChild(m.Name));local ac,a=original:GetBoundingBox();local bc,b=m:GetBoundingBox();assert((a-b).Magnitude<.02,'Size changed '..m.Name)
 local scale=a/b
 for _,p in m:GetChildren() do if p:IsA('BasePart')then if p:GetAttribute('WheelId')then p:Destroy()else local q=p.Position-bc.Position;p.Size=p.Size*scale;p.CFrame=CFrame.new(ac.Position+q*scale)*p.CFrame.Rotation end end end
 for _,p in original:GetChildren()do if p:IsA('BasePart')and p:GetAttribute('WheelId')then p:Clone().Parent=m end end
 local _,exact=m:GetBoundingBox();assert((a-exact).Magnitude<.00002,'Exact fit preservation failed '..m.Name)
 local originalWheels={};for _,p in original:GetChildren() do local id=p:GetAttribute('WheelId');if id then originalWheels[id]={pivot=p:GetAttribute('WheelPivot'),radius=p:GetAttribute('WheelRadius')}end end
 for _,p in m:GetChildren()do local id=p:GetAttribute('WheelId');if id then local w=assert(originalWheels[id]);assert((w.pivot-p:GetAttribute('WheelPivot')).Magnitude<.002 and math.abs(w.radius-p:GetAttribute('WheelRadius'))<.002,'Wheel geometry changed')end end
 for k,v in original:GetAttributes() do if k~='VisualRevision' then m:SetAttribute(k,v)end end""")
(P/'install-fusions.edit.luau').write_text(s)
