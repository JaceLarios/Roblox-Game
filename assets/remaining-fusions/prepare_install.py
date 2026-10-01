from pathlib import Path
P=Path(__file__).resolve().parent;source=P.parent/'model-import-20261001'
code=(source/'import.edit.luau').read_text().replace('AllModelImport','RemainingModelImport').replace('AllModelsStaging_','RemainingModelsStaging_').replace('model-import-20261001/data/','remaining-fusions/import/').replace('model-import-20261001/manifest.json','remaining-fusions/import/manifest.json')
(P/'import.edit.luau').write_text(code)
code=(source/'install.edit.luau').read_text().replace('AllModelImport','RemainingModelImport').replace('AllModelsVerification','RemainingModelsVerification').replace('BeforeAllModels_','BeforeRemainingModels_').replace('#models==25', '#models==52').replace('Expected 25 models','Expected 52 models')
code='\n'.join(line for line in code.splitlines()if "stage:WaitForChild('Atomic Albatross')"not in line)
(P/'install.edit.luau').write_text(code+'\n')
code=(source/'snapshot.edit.luau').read_text().replace('AllModelsVerification','RemainingModelsVerification').replace('AllImportProtectedBefore','RemainingImportProtectedBefore')
(P/'snapshot.edit.luau').write_text(code)
print('Prepared isolated staging, validation and rollback scripts for 52 models.')
