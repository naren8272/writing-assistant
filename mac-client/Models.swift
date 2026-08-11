import Foundation
struct RewriteRequest:Codable{let text:String}
struct RewriteSuggestion:Codable,Identifiable{var id:String{mode};let mode:String;let text:String}
struct RewriteResponse:Codable{let suggestions:[RewriteSuggestion]}
