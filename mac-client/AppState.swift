import SwiftUI
@MainActor final class AppState:ObservableObject{@Published var input="";@Published var suggestions:[RewriteSuggestion]=[];@Published var loading=false;@Published var error:String?
func rewrite(){let t=input.trimmingCharacters(in:.whitespacesAndNewlines);guard !t.isEmpty else{return};loading=true;error=nil;Task{do{suggestions=try await APIClient().rewrite(text:t).suggestions}catch let e{self.error=e.localizedDescription};loading=false}}}
