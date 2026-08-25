// Falls Utility eine Objective-C-Klasse ist, hier importieren (z.B. #import "Utility.h")

- (void)save {
    [Utility saveWithKey:@"regions" value:arrayRegions];  // <- Utility muss existieren
    [Utility saveIntWithKey:@"regionsId" value:self.regionsId];
    ...
}
