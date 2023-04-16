use darling::{
    ast::{self},
    FromDeriveInput, FromField, FromVariant,
};
use proc_macro::TokenStream;
use proc_macro2::{Ident, TokenStream as TokenStream2};
use quote::{quote, ToTokens};
use syn::DeriveInput;

#[proc_macro_derive(Arma, attributes(arma))]
/// Creates the to_arma function based on the attributes for this struct
pub fn derive_arma_struct(input: TokenStream) -> TokenStream {
    let input = syn::parse_macro_input!(input as DeriveInput);

    let derived_input = ArmaReceiver::from_derive_input(&input).unwrap();
    quote! { #derived_input }.into()
}

#[derive(Debug, FromDeriveInput)]
#[darling(attributes(arma))]
struct ArmaReceiver {
    ident: syn::Ident,
    data: ast::Data<ArmaVariantReceiver, ArmaFieldReceiver>,
}

#[derive(Debug, FromVariant)]
#[darling(attributes(arma))]
struct ArmaVariantReceiver {
    ident: syn::Ident,
    fields: ast::Fields<ArmaFieldReceiver>,

    #[darling(default)]
    function: String,
}

#[derive(Debug, FromField)]
#[darling(attributes(arma))]
struct ArmaFieldReceiver {
    ident: Option<syn::Ident>,

    #[darling(default)]
    skip: bool,
}

impl ToTokens for ArmaReceiver {
    fn to_tokens(&self, tokens: &mut TokenStream2) {
        let ArmaReceiver {
            ref ident,
            ref data,
        } = *self;

        let data = data.as_ref();
        match data {
            ast::Data::Enum(variant) => arma_enum(ident, tokens, &variant),
            ast::Data::Struct(s) => arma_struct(ident, tokens, &s.fields),
        };
    }
}

fn arma_enum(ident: &Ident, tokens: &mut TokenStream2, variant: &Vec<&ArmaVariantReceiver>) {
    // Creates to_arma() calls for the variants
    let into_arma = variant
        .iter()
        .filter_map(|v| {
            if v.fields.is_empty() {
                return None;
            }

            let variant = &v.ident;

            Some(quote! {
                #ident::#variant(ref o) => o.to_arma()
            })
        })
        .collect::<Vec<_>>();

    // Links the enum variants to an SQF function, configurable via #[arma(function = "NAME")]
    let sqf_functions = variant
        .iter()
        .filter_map(|v| {
            if v.function.is_empty() {
                return None;
            }

            let variant = &v.ident;
            let function = &v.function;

            Some(quote! {
                #ident::#variant(_) => #function
            })
        })
        .collect::<Vec<_>>();

    // Forwards the attributes call to the internal value
    let attributes = variant
        .iter()
        .filter_map(|v| {
            if v.fields.is_empty() {
                return None;
            }

            let variant = &v.ident;

            Some(quote! {
                #ident::#variant(ref o) => o.attributes()
            })
        })
        .collect::<Vec<_>>();

    // TODO
    let territory_id = variant
        .iter()
        .filter_map(|v| {
            if v.fields.is_empty() {
                return None;
            }

            let variant = &v.ident;

            Some(quote! {
                #ident::#variant(ref mut o) => o.territory_id()
            })
        })
        .collect::<Vec<_>>();

    // Tokens!
    tokens.extend(quote! {
        impl IntoArma for #ident {
            fn to_arma(&self) -> ArmaValue {
                match self {
                    #(#into_arma,)*
                    _ => ArmaValue::Null,
                }
            }
        }

        impl #ident {
            pub fn sqf_function(&self) -> &str {
                match self {
                    #(#sqf_functions,)*
                    _ => "",
                }
            }

            pub fn attributes(&self) -> &[&str] {
                match self {
                    #(#attributes,)*
                    _ => &[],
                }
            }

            pub fn territory_id(&mut self) -> Option<&mut String> {
                match self {
                    #(#territory_id,)*
                    _ => None,
                }
            }
        }
    });
}

fn arma_struct(ident: &Ident, tokens: &mut TokenStream2, fields: &Vec<&ArmaFieldReceiver>) {
    let to_arma = fields
        .iter()
        .filter_map(|field| {
            if field.ident.is_none() {
                return None;
            }

            if field.skip {
                return None;
            }

            Some(field.ident.as_ref().unwrap().to_owned())
        })
        .collect::<Vec<_>>();

    // For the attributes method. Includes all fields
    let attributes = fields
        .iter()
        .filter_map(|field| {
            if field.ident.is_none() {
                return None;
            }

            Some(field.ident.as_ref().unwrap().to_owned())
        })
        .collect::<Vec<_>>();

    let mut territory_id = quote! { None };

    fields.iter().for_each(|field| {
        let Some(i) = field.ident.as_ref() else {
            return;
        };

        if i == "territory_id" {
            territory_id = quote! { Some(&mut self.territory_id) };
            return;
        }
    });

    tokens.extend(quote! {
        impl arma_rs::IntoArma for #ident {
            fn to_arma(&self) -> arma_rs::Value {
                let mut vec: Vec<Vec<arma_rs::Value>> = Vec::new();

                #(
                    vec.push(vec![stringify!(#to_arma).to_arma(), self.#to_arma.to_arma()]);
                )*

                vec.to_arma()
            }
        }

        impl #ident {
            pub fn attributes(&self) -> &[&str] {
                &[#(stringify!(#attributes)),*]
            }

            pub fn territory_id(&mut self) -> Option<&mut String> {
                #territory_id
            }
        }
    });
}
